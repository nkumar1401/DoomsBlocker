package com.doomsblocker.app

import android.accessibilityservice.AccessibilityService
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import java.util.Locale

class DoomsAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "DoomsAccessibility"
        private const val YOUTUBE_PACKAGE = "com.google.android.youtube"
        private const val INSTAGRAM_PACKAGE = "com.instagram.android"
    }

    private lateinit var prefs: AppPreferences
    private val handler = Handler(Looper.getMainLooper())

    private var activePackage: String? = null
    private var isInsideShorts = false
    private var isInsideReels = false
    private var lastActiveTimeMillis = 0L
    private var lastLockActionTimeMillis = 0L

    private fun canTriggerLockAction(): Boolean {
        val now = System.currentTimeMillis()
        if (now - lastLockActionTimeMillis < 2500L) {
            return false
        }
        lastLockActionTimeMillis = now
        return true
    }

    private fun destroyBackgroundMediaAndPlayer(pkg: String = YOUTUBE_PACKAGE) {
        // 1. Immediately request transient audio focus to kill/silence any active audio stream
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (audioManager != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                        .setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                .build()
                        )
                        .build()
                    audioManager.requestAudioFocus(focusRequest)
                } else {
                    @Suppress("DEPRECATION")
                    audioManager.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                }

                // Dispatch PAUSE and STOP key events
                audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE))
                audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PAUSE))
                audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_STOP))
                audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_STOP))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error pausing audio focus: ${e.message}")
        }

        // 2. Press BACK to exit playback activity so YouTube does not enter floating Picture-in-Picture
        performGlobalAction(GLOBAL_ACTION_BACK)

        // 3. Kill background processes to destroy floating PiP mini-player
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            am?.killBackgroundProcesses(pkg)
            if (pkg != YOUTUBE_PACKAGE) {
                am?.killBackgroundProcesses(YOUTUBE_PACKAGE)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error killing background processes: ${e.message}")
        }
    }

    private fun dismissPictureInPictureIfPresent() {
        try {
            val windowList = windows
            for (win in windowList) {
                var isPip = false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    try {
                        val method = win.javaClass.getMethod("isInPictureInPictureMode")
                        isPip = method.invoke(win) as? Boolean ?: false
                    } catch (_: Exception) {}
                }
                if (!isPip) {
                    val bounds = Rect()
                    win.getBoundsInScreen(bounds)
                    val displayMetrics = resources.displayMetrics
                    if (win.type == AccessibilityWindowInfo.TYPE_APPLICATION &&
                        bounds.width() < displayMetrics.widthPixels * 0.7 &&
                        bounds.height() < displayMetrics.heightPixels * 0.7 &&
                        bounds.width() > 50) {
                        isPip = true
                    }
                }

                if (isPip) {
                    val root = win.root
                    if (root != null) {
                        try {
                            val pkg = root.packageName?.toString()
                            if (pkg == YOUTUBE_PACKAGE || pkg == "com.android.systemui") {
                                val closeNodes = root.findAccessibilityNodeInfosByViewId("com.android.systemui:id/dismiss")
                                    ?: root.findAccessibilityNodeInfosByViewId("com.google.android.youtube:id/close_button")
                                if (!closeNodes.isNullOrEmpty()) {
                                    for (node in closeNodes) {
                                        node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                                        node.recycle()
                                    }
                                }
                            }
                        } finally {
                            root.recycle()
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error dismissing PiP: ${e.message}")
        }
    }

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

    private val instagramReelsViewIds = listOf(
        "com.instagram.android:id/clips_viewer_view_pager",
        "com.instagram.android:id/clips_video_container",
        "com.instagram.android:id/reel_viewer_root",
        "com.instagram.android:id/clips_viewer_container",
        "com.instagram.android:id/clips_swipe_refresh_layout",
        "com.instagram.android:id/clips_viewer",
        "com.instagram.android:id/view_pager"
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
        } else if (pkgName == INSTAGRAM_PACKAGE) {
            handleInstagramEvent(event)
        } else if (prefs.isStudyZoneActive && isSocialOrDistractionApp(pkgName)) {
            handleStudyZoneDistractionEvent(pkgName)
        } else if (prefs.restrictedApps.contains(pkgName)) {
            handleRestrictedAppEvent(pkgName)
        } else {
            isInsideShorts = false
            isInsideReels = false
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
                        if (!canTriggerLockAction()) return
                        Log.d(TAG, "Study Zone Active: Shorts blocked! Showing smooth 5s lock overlay...")
                        destroyBackgroundMediaAndPlayer(YOUTUBE_PACKAGE)
                        dismissPictureInPictureIfPresent()
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
                if (!canTriggerLockAction()) return
                Log.d(TAG, "Nephew Mode active & YouTube locked! Showing lock overlay...")
                destroyBackgroundMediaAndPlayer(YOUTUBE_PACKAGE)
                dismissPictureInPictureIfPresent()
                OverlayLockActivity.start(this, OverlayLockActivity.REASON_YOUTUBE_LOCKED, targetPackage = YOUTUBE_PACKAGE)
                return
            } else {
                // Adult Mode: Allow longform videos, but immediately kick out if user tries to enter Shorts!
                val rootNode = rootInActiveWindow
                if (rootNode != null) {
                    try {
                        val inShortsNow = detectShortsPresence(rootNode)
                        if (inShortsNow) {
                            if (!canTriggerLockAction()) return
                            Log.d(TAG, "Adult Mode: Shorts is in lock window! Showing smooth lock overlay...")
                            destroyBackgroundMediaAndPlayer(YOUTUBE_PACKAGE)
                            dismissPictureInPictureIfPresent()
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

    private fun detectInstagramReelsPresence(root: AccessibilityNodeInfo): Boolean {
        for (id in instagramReelsViewIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (!nodes.isNullOrEmpty()) {
                nodes.forEach { it.recycle() }
                return true
            }
        }
        return scanForInstagramReelsIndicators(root, 0)
    }

    private fun scanForInstagramReelsIndicators(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 25) return false

        val resId = node.viewIdResourceName
        if (resId != null) {
            val lowerId = resId.lowercase(Locale.US)
            if (lowerId.contains("clips_video") ||
                lowerId.contains("clips_viewer") ||
                lowerId.contains("reel_viewer") ||
                lowerId.contains("clips_item")) {
                return true
            }
        }

        val desc = node.contentDescription?.toString()
        if (desc != null) {
            val lowerDesc = desc.lowercase(Locale.US)
            if (lowerDesc.contains("remix reel") ||
                lowerDesc.contains("like reel") ||
                lowerDesc.contains("original audio") ||
                lowerDesc.contains("use audio") ||
                lowerDesc.contains("watch more reels") ||
                (lowerDesc.contains("reels") && lowerDesc.contains("selected"))) {
                return true
            }
        }

        val text = node.text?.toString()
        if (text != null) {
            val lowerText = text.lowercase(Locale.US)
            if (lowerText == "original audio" || lowerText == "use audio" || lowerText == "remix") {
                return true
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val found = scanForInstagramReelsIndicators(child, depth + 1)
                child.recycle()
                if (found) return true
            }
        }
        return false
    }

    private fun handleInstagramEvent(event: AccessibilityEvent) {
        if (prefs.isStudyZoneActive) {
            if (!canTriggerLockAction()) return
            Log.w(TAG, "Study Zone Active: Instagram blocked during study hours! Showing smooth lock...")
            destroyBackgroundMediaAndPlayer(INSTAGRAM_PACKAGE)
            dismissPictureInPictureIfPresent()
            OverlayLockActivity.start(
                this,
                OverlayLockActivity.REASON_STUDY_ZONE,
                prefs.studyZoneName,
                INSTAGRAM_PACKAGE
            )
            return
        }

        val now = System.currentTimeMillis()
        val isShortFormLocked = prefs.youtubeLockUntilTimestamp > now ||
            (prefs.shortsUsedSecondsToday >= prefs.shortsLimitMinutes * 60)

        if (isShortFormLocked) {
            if (!canTriggerLockAction()) return
            Log.d(TAG, "Instagram opened while short-form lockout is active! Showing smooth lock overlay...")
            destroyBackgroundMediaAndPlayer(INSTAGRAM_PACKAGE)
            dismissPictureInPictureIfPresent()
            OverlayLockActivity.start(
                this,
                OverlayLockActivity.REASON_SHORTS_LIMIT,
                targetPackage = INSTAGRAM_PACKAGE
            )
            return
        }

        // Active tracking for Instagram (home feed reels & clips viewer)
        isInsideReels = true
    }

    private fun handleStudyZoneDistractionEvent(pkgName: String) {
        if (!canTriggerLockAction()) return
        Log.w(TAG, "Study Zone Active: Distraction app $pkgName blocked! Showing smooth lock...")
        destroyBackgroundMediaAndPlayer(pkgName)
        dismissPictureInPictureIfPresent()
        OverlayLockActivity.start(
            this,
            OverlayLockActivity.REASON_STUDY_ZONE,
            prefs.studyZoneName,
            pkgName
        )
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
                                if (!canTriggerLockAction()) return
                                Log.w(TAG, "Blocked channel detected: $text! Showing smooth lock overlay...")
                                destroyBackgroundMediaAndPlayer(YOUTUBE_PACKAGE)
                                dismissPictureInPictureIfPresent()
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
        if (prefs.isStudyZoneActive) {
            if (!canTriggerLockAction()) return
            Log.w(TAG, "Study Zone Active: App $pkgName blocked during study hours! Showing smooth lock overlay...")
            destroyBackgroundMediaAndPlayer(pkgName)
            dismissPictureInPictureIfPresent()
            OverlayLockActivity.start(
                this,
                OverlayLockActivity.REASON_STUDY_ZONE,
                prefs.studyZoneName,
                pkgName
            )
            return
        }

        val limitMinutes = prefs.gameLimitMinutes
        val limitSeconds = limitMinutes * 60
        val usedSeconds = prefs.getAppUsageSeconds(pkgName)
        val totalUsed = prefs.getTotalRestrictedAppsUsageSeconds()

        if (usedSeconds >= limitSeconds || totalUsed >= limitSeconds) {
            if (!canTriggerLockAction()) return
            Log.w(TAG, "App $pkgName reached limit of $limitMinutes mins! Showing smooth lock overlay...")
            destroyBackgroundMediaAndPlayer(pkgName)
            dismissPictureInPictureIfPresent()
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
            isInsideReels = false
            if (rootNode != null) {
                try {
                    isInsideShorts = detectShortsPresence(rootNode)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in detectShortsPresence: ${e.message}")
                }
            }
        } else if (windowPkg == INSTAGRAM_PACKAGE) {
            activePackage = INSTAGRAM_PACKAGE
            isInsideShorts = false
            isInsideReels = true

            val isShortFormLocked = prefs.youtubeLockUntilTimestamp > now ||
                (prefs.shortsUsedSecondsToday >= prefs.shortsLimitMinutes * 60)
            if (isShortFormLocked) {
                if (canTriggerLockAction()) {
                    Log.d(TAG, "Periodic tick: Instagram active during short-form lockout! Showing lock overlay...")
                    destroyBackgroundMediaAndPlayer(INSTAGRAM_PACKAGE)
                    dismissPictureInPictureIfPresent()
                    OverlayLockActivity.start(
                        this,
                        OverlayLockActivity.REASON_SHORTS_LIMIT,
                        targetPackage = INSTAGRAM_PACKAGE
                    )
                }
            }
        } else {
            isInsideShorts = false
            isInsideReels = false
        }

        // 1. Unified Short-Form (YouTube Shorts & Instagram Reels) Screen Time Tracking
        val isShortFormActive = (activePackage == YOUTUBE_PACKAGE && isInsideShorts) ||
                                (activePackage == INSTAGRAM_PACKAGE && isInsideReels)

        if (isShortFormActive) {
            prefs.addShortsUsedSeconds(deltaSeconds)
            val usedSec = prefs.shortsUsedSecondsToday
            val limitSec = prefs.shortsLimitMinutes * 60
            val targetPkg = activePackage ?: YOUTUBE_PACKAGE

            Log.d(TAG, "Unified Short-Form Active ($targetPkg): $usedSec s / $limitSec s limit (Limit: ${prefs.shortsLimitMinutes} min)")

            if (usedSec >= limitSec) {
                if (!canTriggerLockAction()) return
                Log.w(TAG, "Shorts/Reels limit hit ($usedSec >= $limitSec s)! Enforcing Lockout for ${prefs.shortsLockDurationMinutes} min!")
                val lockDurationMillis = prefs.shortsLockDurationMinutes * 60 * 1000L
                prefs.youtubeLockUntilTimestamp = now + lockDurationMillis

                destroyBackgroundMediaAndPlayer(targetPkg)
                dismissPictureInPictureIfPresent()
                if (prefs.isNephewModeEnabled && targetPkg == YOUTUBE_PACKAGE) {
                    OverlayLockActivity.start(this, OverlayLockActivity.REASON_YOUTUBE_LOCKED, targetPackage = YOUTUBE_PACKAGE)
                } else {
                    OverlayLockActivity.start(this, OverlayLockActivity.REASON_SHORTS_LIMIT, targetPackage = targetPkg)
                }
                isInsideShorts = false
                isInsideReels = false
            }
        }
        rootNode?.recycle()

        // 2. Restricted Game Apps Time Tracking (Smooth 5s lock overlay)
        val currentPkg = activePackage
        if (currentPkg != null && prefs.restrictedApps.contains(currentPkg)) {
            if (prefs.isStudyZoneActive) {
                if (!canTriggerLockAction()) return
                Log.w(TAG, "Study Zone Active: $currentPkg opened during focus hours! Showing smooth lock overlay...")
                destroyBackgroundMediaAndPlayer(currentPkg)
                dismissPictureInPictureIfPresent()
                OverlayLockActivity.start(
                    this,
                    OverlayLockActivity.REASON_STUDY_ZONE,
                    prefs.studyZoneName,
                    currentPkg
                )
            } else {
                prefs.addAppUsageSeconds(currentPkg, deltaSeconds)
                val totalUsed = prefs.getTotalRestrictedAppsUsageSeconds()
                val limitSec = prefs.gameLimitMinutes * 60

                Log.d(TAG, "Restricted App ($currentPkg) Active: $totalUsed s / $limitSec s limit")

                if (totalUsed >= limitSec) {
                    if (!canTriggerLockAction()) return
                    Log.w(TAG, "Game limit reached ($totalUsed >= $limitSec s)! Showing smooth lock overlay...")
                    destroyBackgroundMediaAndPlayer(currentPkg)
                    dismissPictureInPictureIfPresent()
                    OverlayLockActivity.start(this, OverlayLockActivity.REASON_GAME_LIMIT, getAppLabel(currentPkg), currentPkg)
                }
            }
        }
    }

    private fun isSocialOrDistractionApp(pkgName: String): Boolean {
        val lower = pkgName.lowercase(Locale.US)
        return lower.contains("instagram") ||
                lower.contains("snapchat") ||
                lower.contains("tiktok") ||
                lower.contains("facebook.katana") ||
                lower.contains("twitter") ||
                lower.contains("reddit")
    }

    private fun exitShortsPlayer() {
        destroyBackgroundMediaAndPlayer(YOUTUBE_PACKAGE)
        dismissPictureInPictureIfPresent()
    }

    private fun ejectToHomeScreen(pkgToKill: String? = null) {
        val target = pkgToKill ?: YOUTUBE_PACKAGE
        destroyBackgroundMediaAndPlayer(target)
        dismissPictureInPictureIfPresent()
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
