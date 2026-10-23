package com.doomsblocker.app

import android.accessibilityservice.AccessibilityService
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.Locale

class DoomsAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "DoomsAccessibility"
        private const val YOUTUBE_PACKAGE = "com.google.android.youtube"
    }

    private lateinit var prefs: AppPreferences
    private val handler = Handler(Looper.getMainLooper())

    private var activePackage: String? = null
    private var isInsideShorts = false
    private var lastActiveTimeMillis = 0L

    // Dedicated YouTube Shorts View & Layout IDs
    private val shortsViewIds = listOf(
        "com.google.android.youtube:id/reel_watch_fragment_root",
        "com.google.android.youtube:id/reel_recycler",
        "com.google.android.youtube:id/reel_player_page_view",
        "com.google.android.youtube:id/shorts_player_view",
        "com.google.android.youtube:id/reel_player_fragment",
        "com.google.android.youtube:id/shorts_container",
        "com.google.android.youtube:id/reel_container",
        "com.google.android.youtube:id/reel_recycler_view",
        "com.google.android.youtube:id/shorts_view_pager"
    )

    private val channelNameViewIds = listOf(
        "com.google.android.youtube:id/channel_name",
        "com.google.android.youtube:id/owner_name",
        "com.google.android.youtube:id/channel_title"
    )

    // Periodic 1-second tick to continuously track active screen time in background
    private val tickerRunnable = object : Runnable {
        override fun run() {
            onPeriodicTick()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs = AppPreferences(applicationContext)
        lastActiveTimeMillis = System.currentTimeMillis()

        // Ensure background monitor watchdog is running
        try {
            AppMonitorForegroundService.start(this)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting monitor service: ${e.message}")
        }

        handler.post(tickerRunnable)
        Log.d(TAG, "DoomsAccessibilityService connected successfully")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val pkgName = event.packageName?.toString() ?: return

        // Ignore system UI overlays (status bar, notifications, keyboard) so they don't corrupt activePackage
        if (pkgName == "com.android.systemui" ||
            pkgName == "com.google.android.inputmethod.latin" ||
            pkgName.startsWith("com.android.systemui")) {
            return
        }

        activePackage = pkgName

        if (pkgName == YOUTUBE_PACKAGE) {
            handleYouTubeEvent(event)
        } else if (prefs.restrictedApps.contains(pkgName)) {
            handleRestrictedAppEvent(pkgName)
        } else {
            isInsideShorts = false
        }
    }

    private fun handleYouTubeEvent(event: AccessibilityEvent) {
        // 0. Library Study Zone handling (Immediate 100% block of Shorts)
        if (prefs.isStudyZoneActive) {
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                try {
                    val inShortsNow = detectShortsPresence(rootNode)
                    if (inShortsNow) {
                        Log.d(TAG, "Study Zone Active: Shorts blocked! Exiting...")
                        exitShortsPlayer()
                        OverlayLockActivity.start(this, OverlayLockActivity.REASON_STUDY_ZONE, prefs.studyZoneName, YOUTUBE_PACKAGE)
                        return
                    }
                } finally {
                    rootNode.recycle()
                }
            }
        }

        // 1. Strict Lockout handling
        if (prefs.isYouTubeLocked) {
            if (prefs.isNephewModeEnabled) {
                // Nephew Mode: Lock ENTIRE YouTube application
                Log.d(TAG, "Nephew Mode active & YouTube locked! Ejecting to home...")
                ejectToHomeScreen(YOUTUBE_PACKAGE)
                OverlayLockActivity.start(this, OverlayLockActivity.REASON_YOUTUBE_LOCKED, targetPackage = YOUTUBE_PACKAGE)
                return
            } else {
                // Adult Mode: Allow longform videos, but immediately kick out if user tries to enter Shorts!
                val rootNode = rootInActiveWindow
                if (rootNode != null) {
                    try {
                        val inShortsNow = detectShortsPresence(rootNode)
                        if (inShortsNow) {
                            Log.d(TAG, "Adult Mode: Shorts is in lock window! Exiting Shorts...")
                            exitShortsPlayer()
                            OverlayLockActivity.start(this, OverlayLockActivity.REASON_SHORTS_LIMIT, targetPackage = YOUTUBE_PACKAGE)
                            return
                        }
                    } finally {
                        rootNode.recycle()
                    }
                }
            }
        }

        val rootNode = rootInActiveWindow ?: return

        try {
            // 2. Check for Blocked Channels
            checkAndBlockRestrictedChannels(rootNode)

            // 3. Inspect if currently in Shorts player
            val inShortsNow = detectShortsPresence(rootNode)
            isInsideShorts = inShortsNow
        } finally {
            rootNode.recycle()
        }
    }

    private fun detectShortsPresence(root: AccessibilityNodeInfo): Boolean {
        // 1. Direct layout ID matches for Shorts/Reel player
        for (id in shortsViewIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (!nodes.isNullOrEmpty()) {
                nodes.forEach { it.recycle() }
                return true
            }
        }

        // 2. Shorts-specific button: "Remix" only appears inside the Shorts player
        val remixNodes = root.findAccessibilityNodeInfosByText("Remix")
        if (!remixNodes.isNullOrEmpty()) {
            remixNodes.forEach { it.recycle() }
            return true
        }

        // 3. Deep hierarchical scan for reel keywords, descriptions, and action buttons
        return scanForShortsIndicators(root, 0)
    }

    private fun scanForShortsIndicators(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 30) return false

        val resId = node.viewIdResourceName
        if (resId != null) {
            val lowerId = resId.lowercase(Locale.US)
            val isNavOrShelf = lowerId.contains("shelf") || lowerId.contains("pivot") || lowerId.contains("tab")
            if (!isNavOrShelf) {
                if (lowerId.contains("reel") ||
                    lowerId.contains("shorts_player") ||
                    lowerId.contains("shorts_container") ||
                    lowerId.contains("shorts_video") ||
                    lowerId.contains("shorts_surface") ||
                    lowerId.contains("shorts_pager")) {
                    return true
                }
            }
        }

        val desc = node.contentDescription?.toString()
        if (desc != null) {
            val lowerDesc = desc.lowercase(Locale.US)
            if (lowerDesc.contains("remix this") ||
                lowerDesc.contains("remix with") ||
                lowerDesc.contains("dislike this short") ||
                lowerDesc.contains("dislike this video along with") ||
                lowerDesc.contains("create a short using") ||
                lowerDesc.contains("use this sound") ||
                (lowerDesc.contains("dislike") && (lowerDesc.contains("other") || lowerDesc.contains("person") || lowerDesc.contains("along with")))) {
                return true
            }
        }

        val text = node.text?.toString()
        if (text != null) {
            val lowerText = text.lowercase(Locale.US)
            if (lowerText == "remix" || lowerText == "use this sound") {
                return true
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val found = scanForShortsIndicators(child, depth + 1)
                child.recycle()
                if (found) return true
            }
        }
        return false
    }

    private fun checkAndBlockRestrictedChannels(root: AccessibilityNodeInfo) {
        val blockedList = prefs.blockedChannels
        if (blockedList.isEmpty()) return

        for (id in channelNameViewIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (!nodes.isNullOrEmpty()) {
                for (node in nodes) {
                    val text = node.text?.toString()?.trim()
                    if (!text.isNullOrEmpty()) {
                        for (blocked in blockedList) {
                            if (text.contains(blocked, ignoreCase = true)) {
                                Log.w(TAG, "Blocked channel detected: $text! Ejecting...")
                                if (prefs.isNephewModeEnabled) {
                                    ejectToHomeScreen(YOUTUBE_PACKAGE)
                                } else {
                                    exitShortsPlayer()
                                }
                                OverlayLockActivity.start(
                                    this,
                                    OverlayLockActivity.REASON_CHANNEL_BLOCKED,
                                    blocked,
                                    YOUTUBE_PACKAGE
                                )
                                nodes.forEach { it.recycle() }
                                return
                            }
                        }
                    }
                }
                nodes.forEach { it.recycle() }
            }
        }
    }

    private fun handleRestrictedAppEvent(pkgName: String) {
        val limitMinutes = prefs.gameLimitMinutes
        val limitSeconds = limitMinutes * 60
        val usedSeconds = prefs.getAppUsageSeconds(pkgName)
        val totalUsed = prefs.getTotalRestrictedAppsUsageSeconds()

        if (usedSeconds >= limitSeconds || totalUsed >= limitSeconds) {
            Log.w(TAG, "App $pkgName reached limit of $limitMinutes mins! Ejecting to home...")
            ejectToHomeScreen(pkgName)
            OverlayLockActivity.start(this, OverlayLockActivity.REASON_GAME_LIMIT, getAppLabel(pkgName), pkgName)
        }
    }

    private fun onPeriodicTick() {
        val now = System.currentTimeMillis()
        val deltaSeconds = ((now - lastActiveTimeMillis) / 1000).toInt().coerceIn(0, 5)
        lastActiveTimeMillis = now

        if (deltaSeconds <= 0) return

        // Check active foreground window directly
        val rootNode = rootInActiveWindow
        val windowPkg = rootNode?.packageName?.toString() ?: activePackage

        if (windowPkg == YOUTUBE_PACKAGE) {
            activePackage = YOUTUBE_PACKAGE
            if (rootNode != null) {
                try {
                    isInsideShorts = detectShortsPresence(rootNode)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in detectShortsPresence: ${e.message}")
                }
            }
        }

        // 1. YouTube Shorts Screen Time Tracking
        if (activePackage == YOUTUBE_PACKAGE && isInsideShorts) {
            prefs.addShortsUsedSeconds(deltaSeconds)
            val usedSec = prefs.shortsUsedSecondsToday
            val limitSec = prefs.shortsLimitMinutes * 60

            Log.d(TAG, "Shorts Active: $usedSec s / $limitSec s limit (Limit: ${prefs.shortsLimitMinutes} min)")

            if (usedSec >= limitSec) {
                Log.w(TAG, "Shorts limit hit ($usedSec >= $limitSec s)! Enforcing Lockout for ${prefs.shortsLockDurationMinutes} min!")
                val lockDurationMillis = prefs.shortsLockDurationMinutes * 60 * 1000L
                prefs.youtubeLockUntilTimestamp = now + lockDurationMillis

                if (prefs.isNephewModeEnabled) {
                    // In Nephew Mode: Lock ENTIRE YouTube application
                    ejectToHomeScreen(YOUTUBE_PACKAGE)
                    OverlayLockActivity.start(this, OverlayLockActivity.REASON_YOUTUBE_LOCKED, targetPackage = YOUTUBE_PACKAGE)
                } else {
                    // In Adult Mode: Only exit Shorts! Allow longform videos
                    exitShortsPlayer()
                    OverlayLockActivity.start(this, OverlayLockActivity.REASON_SHORTS_LIMIT, targetPackage = YOUTUBE_PACKAGE)
                }
                isInsideShorts = false
            }
        }
        rootNode?.recycle()

        // 2. Restricted Game Time Tracking
        val currentPkg = activePackage
        if (currentPkg != null && prefs.restrictedApps.contains(currentPkg)) {
            prefs.addAppUsageSeconds(currentPkg, deltaSeconds)
            val totalUsed = prefs.getTotalRestrictedAppsUsageSeconds()
            val limitSec = prefs.gameLimitMinutes * 60

            Log.d(TAG, "Restricted App ($currentPkg) Active: $totalUsed s / $limitSec s limit")

            if (totalUsed >= limitSec) {
                ejectToHomeScreen(currentPkg)
                OverlayLockActivity.start(this, OverlayLockActivity.REASON_GAME_LIMIT, getAppLabel(currentPkg), currentPkg)
            }
        }
    }

    private fun exitShortsPlayer() {
        // 1. Immediately pause audio/media so Shorts sound stops
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            audioManager?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE))
            audioManager?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PAUSE))
        } catch (e: Exception) {
            Log.e(TAG, "Error pausing audio: ${e.message}")
        }

        // 2. Press BACK to exit the vertical Shorts player back to YouTube Home / normal video feed
        performGlobalAction(GLOBAL_ACTION_BACK)
    }

    private fun ejectToHomeScreen(pkgToKill: String? = null) {
        // 1. Immediately pause audio/media so playback stops
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            audioManager?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE))
            audioManager?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PAUSE))
        } catch (e: Exception) {
            Log.e(TAG, "Error pausing audio: ${e.message}")
        }

        // 2. Press BACK before going Home so app exits playback/activity
        performGlobalAction(GLOBAL_ACTION_BACK)

        // 3. Kill target package background process to destroy floating/playing windows
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val target = pkgToKill ?: YOUTUBE_PACKAGE
            am?.killBackgroundProcesses(target)
            if (target != YOUTUBE_PACKAGE) {
                am?.killBackgroundProcesses(YOUTUBE_PACKAGE)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error killing background process: ${e.message}")
        }

        // 4. Return to phone Home Screen
        performGlobalAction(GLOBAL_ACTION_HOME)
        try {
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
            }
            startActivity(homeIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Error redirecting to home: ${e.message}")
        }
    }

    private fun getAppLabel(pkgName: String): String {
        return try {
            val pm = packageManager
            val info = pm.getApplicationInfo(pkgName, 0)
            pm.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            pkgName
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "DoomsAccessibilityService interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(tickerRunnable)
    }
}
