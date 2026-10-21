package com.doomsblocker.app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

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

    // Known YouTube Shorts layout IDs and signatures
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

    // Periodic tick to track active seconds continuously
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
        handler.post(tickerRunnable)
        Log.d(TAG, "DoomsAccessibilityService connected successfully")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val pkgName = event.packageName?.toString() ?: return
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
        // 1. Strict Lockout Check: If YouTube is currently locked, redirect to Home immediately!
        if (prefs.isYouTubeLocked) {
            Log.d(TAG, "YouTube is in active lock window! Ejecting to home...")
            ejectToHomeScreen()
            OverlayLockActivity.start(this, OverlayLockActivity.REASON_YOUTUBE_LOCKED)
            return
        }

        val rootNode = rootInActiveWindow ?: return

        try {
            // 2. Check for Blocked Channels
            checkAndBlockRestrictedChannels(rootNode)

            // 3. Detect if currently in Shorts player
            val inShortsNow = detectShortsPresence(rootNode)
            if (inShortsNow) {
                isInsideShorts = true
            } else if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                isInsideShorts = false
            }
        } finally {
            rootNode.recycle()
        }
    }

    private fun detectShortsPresence(root: AccessibilityNodeInfo): Boolean {
        // Fast ID match
        for (id in shortsViewIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (!nodes.isNullOrEmpty()) {
                nodes.forEach { it.recycle() }
                return true
            }
        }

        // Secondary text match: Check buttons with "Remix" text
        val remixNodes = root.findAccessibilityNodeInfosByText("Remix")
        if (!remixNodes.isNullOrEmpty()) {
            remixNodes.forEach { it.recycle() }
            return true
        }

        // Structural check for content descriptions
        return hasShortsDescription(root, 0)
    }

    private fun hasShortsDescription(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 8) return false
        val desc = node.contentDescription?.toString()
        if (desc != null) {
            if (desc.contains("Dislike this video", ignoreCase = true) ||
                desc.contains("Remix this video", ignoreCase = true) ||
                desc.equals("Shorts", ignoreCase = true)) {
                return true
            }
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (hasShortsDescription(child, depth + 1)) {
                child?.recycle()
                return true
            }
            child?.recycle()
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
                                Log.w(TAG, "Blocked channel detected: $text! Ejecting to home...")
                                ejectToHomeScreen()
                                OverlayLockActivity.start(
                                    this,
                                    OverlayLockActivity.REASON_CHANNEL_BLOCKED,
                                    blocked
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

        if (usedSeconds >= limitSeconds) {
            Log.w(TAG, "App $pkgName reached limit of $limitMinutes mins! Ejecting to home...")
            ejectToHomeScreen()
            OverlayLockActivity.start(this, OverlayLockActivity.REASON_GAME_LIMIT, getAppLabel(pkgName))
        }
    }

    private fun onPeriodicTick() {
        val now = System.currentTimeMillis()
        val deltaSeconds = ((now - lastActiveTimeMillis) / 1000).toInt().coerceIn(0, 5)
        lastActiveTimeMillis = now

        if (deltaSeconds <= 0) return

        // 1. YouTube Shorts Screen Time
        if (activePackage == YOUTUBE_PACKAGE && isInsideShorts) {
            prefs.addShortsUsedSeconds(deltaSeconds)
            val usedSec = prefs.shortsUsedSecondsToday
            val limitSec = prefs.shortsLimitMinutes * 60

            Log.d(TAG, "Shorts Active: $usedSec s / $limitSec s limit")

            if (usedSec >= limitSec) {
                Log.w(TAG, "Shorts limit hit! Enforcing YouTube Lockout for ${prefs.shortsLockDurationMinutes} min!")
                val lockDurationMillis = prefs.shortsLockDurationMinutes * 60 * 1000L
                prefs.youtubeLockUntilTimestamp = now + lockDurationMillis

                // Forcefully redirect to phone Home Screen and display lock screen
                ejectToHomeScreen()
                OverlayLockActivity.start(this, OverlayLockActivity.REASON_SHORTS_LIMIT)
                isInsideShorts = false
            }
        }

        // 2. Restricted Game Time
        val currentPkg = activePackage
        if (currentPkg != null && prefs.restrictedApps.contains(currentPkg)) {
            prefs.addAppUsageSeconds(currentPkg, deltaSeconds)
            val usedSec = prefs.getAppUsageSeconds(currentPkg)
            val limitSec = prefs.gameLimitMinutes * 60

            Log.d(TAG, "Restricted App ($currentPkg) Active: $usedSec s / $limitSec s limit")

            if (usedSec >= limitSec) {
                ejectToHomeScreen()
                OverlayLockActivity.start(this, OverlayLockActivity.REASON_GAME_LIMIT, getAppLabel(currentPkg))
            }
        }
    }

    private fun ejectToHomeScreen() {
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
