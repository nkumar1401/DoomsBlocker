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
        private const val SNAPCHAT_PACKAGE = "com.snapchat.android"
        private const val SHARECHAT_PACKAGE = "in.mohalla.sharechat"
        private const val MOJ_PACKAGE = "in.mohalla.video"
        private const val JOSH_PACKAGE = "com.eterno.shortvideos"
    }

    private lateinit var prefs: AppPreferences
    private val handler = Handler(Looper.getMainLooper())

    private var activePackage: String? = null
    private var isInsideShorts = false
    private var isInsideReels = false
    private var isInsideSpotlight = false
    private var isInsidePureShortForm = false
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
        "com.google.android.youtube:id/channel_title",
        "com.google.android.youtube:id/video_owner",
        "com.google.android.youtube:id/collapsed_metadata",
        "com.google.android.youtube:id/expandable_metadata",
        "com.google.android.youtube:id/metadata_line",
        "com.google.android.youtube:id/byline",
        "com.google.android.youtube:id/channel_avatar"
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

    private val snapchatSpotlightViewIds = listOf(
        "com.snapchat.android:id/spotlight_tab",
        "com.snapchat.android:id/spotlight_recycler",
        "com.snapchat.android:id/spotlight_fragment",
        "com.snapchat.android:id/spotlight_viewer",
        "com.snapchat.android:id/spotlight_page_container",
        "com.snapchat.android:id/vertical_player_page",
        "com.snapchat.android:id/spotlight_fullscreen",
        "com.snapchat.android:id/spotlight_video_container"
    )

    private fun isPureShortFormPackage(pkgName: String): Boolean {
        return pkgName == SHARECHAT_PACKAGE ||
               pkgName == MOJ_PACKAGE ||
               pkgName == JOSH_PACKAGE
    }

    private fun detectSnapchatSpotlightPresence(root: AccessibilityNodeInfo): Boolean {
        // Immunity for Chat & Camera: If chat input or conversation list is active, it is NOT Spotlight!
        val chatNodes = root.findAccessibilityNodeInfosByViewId("com.snapchat.android:id/chat_input_text")
        if (!chatNodes.isNullOrEmpty()) {
            chatNodes.forEach { it.recycle() }
            return false
        }
        val conversationNodes = root.findAccessibilityNodeInfosByViewId("com.snapchat.android:id/conversation_list")
        if (!conversationNodes.isNullOrEmpty()) {
            conversationNodes.forEach { it.recycle() }
            return false
        }

        for (id in snapchatSpotlightViewIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (!nodes.isNullOrEmpty()) {
                nodes.forEach { it.recycle() }
                return true
            }
        }
        return scanForSnapchatSpotlightIndicators(root, 0)
    }

    private fun scanForSnapchatSpotlightIndicators(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 25) return false

        val resId = node.viewIdResourceName
        if (resId != null) {
            val lowerId = resId.lowercase(Locale.US)
            if (lowerId.contains("spotlight") && !lowerId.contains("icon") && !lowerId.contains("tab_icon")) {
                return true
            }
        }

        val desc = node.contentDescription?.toString()
        if (desc != null) {
            val lowerDesc = desc.lowercase(Locale.US)
            if (lowerDesc.contains("remix this snap") ||
                lowerDesc.contains("sound used in this snap") ||
                lowerDesc.contains("spotlight video") ||
                (lowerDesc.contains("spotlight") && lowerDesc.contains("selected"))) {
                return true
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val found = scanForSnapchatSpotlightIndicators(child, depth + 1)
                child.recycle()
                if (found) return true
            }
        }
        return false
    }

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

        // Kids Mode Social Media Check: Complete 24/7 block
        if (prefs.isKidsModeEnabled && isSocialOrDistractionApp(pkgName)) {
            if (canTriggerLockAction()) {
                Log.w(TAG, "Kids Mode Active: Social app $pkgName blocked 24/7! Showing lock overlay...")
                destroyBackgroundMediaAndPlayer(pkgName)
                dismissPictureInPictureIfPresent()
                OverlayLockActivity.start(
                    this,
                    OverlayLockActivity.REASON_KIDS_SOCIAL_BLOCKED,
                    targetPackage = pkgName
                )
            }
            return
        }

        if (pkgName == YOUTUBE_PACKAGE && prefs.isShortFormMonitored(YOUTUBE_PACKAGE)) {
            handleYouTubeEvent(event)
        } else if (pkgName == INSTAGRAM_PACKAGE && prefs.isShortFormMonitored(INSTAGRAM_PACKAGE)) {
            handleInstagramEvent(event)
        } else if (pkgName == SNAPCHAT_PACKAGE && prefs.isShortFormMonitored(SNAPCHAT_PACKAGE)) {
            handleSnapchatEvent(event)
        } else if (isPureShortFormPackage(pkgName) && prefs.isShortFormMonitored(pkgName)) {
            handlePureShortFormEvent(event, pkgName)
        } else if (prefs.isStudyZoneActive && isSocialOrDistractionApp(pkgName)) {
            handleStudyZoneDistractionEvent(pkgName)
        } else if (prefs.restrictedApps.contains(pkgName)) {
            handleRestrictedAppEvent(pkgName)
        } else {
            isInsideShorts = false
            isInsideReels = false
            isInsideSpotlight = false
            isInsidePureShortForm = false
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

        // 0.1 Kids Mode: 0-second instant lockout for YouTube Shorts!
        if (prefs.isKidsModeEnabled) {
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                try {
                    val inShortsNow = detectShortsPresence(rootNode)
                    if (inShortsNow) {
                        if (!canTriggerLockAction()) return
                        Log.d(TAG, "Kids Mode Active: Shorts opened! Zero-tolerance 0s block. Showing lock overlay...")
                        destroyBackgroundMediaAndPlayer(YOUTUBE_PACKAGE)
                        dismissPictureInPictureIfPresent()
                        OverlayLockActivity.start(
                            this,
                            OverlayLockActivity.REASON_KIDS_SHORTS_BLOCKED,
                            targetPackage = YOUTUBE_PACKAGE
                        )
                        return
                    }
                } finally {
                    rootNode.recycle()
                }
            }
        }

        // 1. Strict Lockout handling
        val now = System.currentTimeMillis()
        if (prefs.isKidsModeEnabled) {
            // Check if 30-minute cooldown is active
            if (prefs.youtubeLockUntilTimestamp > now) {
                if (!canTriggerLockAction()) return
                Log.d(TAG, "Kids Mode Active: YouTube in 30-min cooldown! Showing lock overlay...")
                destroyBackgroundMediaAndPlayer(YOUTUBE_PACKAGE)
                dismissPictureInPictureIfPresent()
                OverlayLockActivity.start(this, OverlayLockActivity.REASON_YOUTUBE_LOCKED, targetPackage = YOUTUBE_PACKAGE)
                return
            } else if (prefs.youtubeLockUntilTimestamp > 0L) {
                // Cooldown expired! Reset allowance for new session
                prefs.youtubeLockUntilTimestamp = 0L
                prefs.shortsUsedSecondsToday = 0
            }

            // Check if daily session limit reached
            if (prefs.shortsUsedSecondsToday >= prefs.shortsLimitMinutes * 60) {
                if (!canTriggerLockAction()) return
                Log.w(TAG, "Kids Mode: YouTube limit reached (${prefs.shortsUsedSecondsToday}s)! Setting 30-min cooldown...")
                prefs.youtubeLockUntilTimestamp = now + 30 * 60 * 1000L
                destroyBackgroundMediaAndPlayer(YOUTUBE_PACKAGE)
                dismissPictureInPictureIfPresent()
                OverlayLockActivity.start(this, OverlayLockActivity.REASON_YOUTUBE_LOCKED, targetPackage = YOUTUBE_PACKAGE)
                return
            }
        } else {
            // Adult Focus Mode
            val isYtLockedNow = prefs.isYouTubeLocked
            if (isYtLockedNow) {
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
        val displayMetrics = resources.displayMetrics
        val minFullscreenHeight = (displayMetrics.heightPixels * 0.50).toInt()
        val minFullscreenWidth = (displayMetrics.widthPixels * 0.50).toInt()
        val rect = Rect()

        // 1. Direct layout ID matches for an active, visible full-screen vertical Shorts player
        // (Handles Shorts opened from bottom tab, tapped from Home feed shelf, search, or external link)
        for (id in shortsViewIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (!nodes.isNullOrEmpty()) {
                for (node in nodes) {
                    if (node.isVisibleToUser) {
                        node.getBoundsInScreen(rect)
                        val resId = node.viewIdResourceName?.lowercase(Locale.US) ?: ""
                        val isShelf = resId.contains("shelf") || resId.contains("pivot") ||
                                      resId.contains("carousel") || resId.contains("tray")
                        if (!isShelf && rect.height() >= minFullscreenHeight && rect.width() >= minFullscreenWidth) {
                            nodes.forEach { it.recycle() }
                            return true
                        }
                    }
                }
                nodes.forEach { it.recycle() }
            }
        }

        // 2. If a regular long-form video player is visible, user is watching educational long-form content
        // (Invariant 2 Exemption: timer immediately pauses)
        if (isWatchPlayerActive(root)) {
            return false
        }

        // 3. Check if the bottom navigation bar has the "Shorts" tab explicitly selected
        val shortsTabNodes = root.findAccessibilityNodeInfosByText("Shorts")
        if (!shortsTabNodes.isNullOrEmpty()) {
            for (node in shortsTabNodes) {
                if (node.isVisibleToUser && (node.isSelected || node.parent?.isSelected == true)) {
                    shortsTabNodes.forEach { it.recycle() }
                    return true
                }
            }
            shortsTabNodes.forEach { it.recycle() }
        }

        // 4. Deep hierarchical scan for visible Shorts player action buttons & indicators
        if (scanForShortsIndicators(root, 0)) {
            return true
        }

        // 5. Check if the horizontal Shorts shelf is active and visible on the Home feed
        if (isShortsShelfActiveOnScreen(root)) {
            return true
        }

        return false
    }

    private fun isWatchPlayerActive(root: AccessibilityNodeInfo): Boolean {
        // If the user is on the Search screen, it is never a watch player
        if (isSearchOrBrowseFeedActive(root)) return false

        val watchPlayerIds = listOf(
            "com.google.android.youtube:id/watch_player",
            "com.google.android.youtube:id/movie_player"
        )
        val rect = Rect()
        for (id in watchPlayerIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (!nodes.isNullOrEmpty()) {
                for (node in nodes) {
                    if (node.isVisibleToUser) {
                        node.getBoundsInScreen(rect)
                        // A genuine active watch player must occupy a prominent area at the top
                        if (rect.height() >= 300 && rect.width() >= 400) {
                            nodes.forEach { it.recycle() }
                            return true
                        }
                    }
                }
                nodes.forEach { it.recycle() }
            }
        }
        return false
    }

    private fun isSearchOrBrowseFeedActive(root: AccessibilityNodeInfo): Boolean {
        val searchAndFeedIds = listOf(
            // Search screen & suggestions
            "com.google.android.youtube:id/search_edit_text",
            "com.google.android.youtube:id/search_box",
            "com.google.android.youtube:id/results",
            "com.google.android.youtube:id/search_results",
            "com.google.android.youtube:id/suggestions_list",
            "com.google.android.youtube:id/search_clear_button",
            // Feed lists & inline overview previews
            "com.google.android.youtube:id/inline_player",
            "com.google.android.youtube:id/feed_swipe_refresh_layout",
            "com.google.android.youtube:id/feed_filter_bar"
        )
        for (id in searchAndFeedIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (!nodes.isNullOrEmpty()) {
                val isVisible = nodes.any { it.isVisibleToUser }
                nodes.forEach { it.recycle() }
                if (isVisible) return true
            }
        }
        return false
    }

    private fun isShortsShelfActiveOnScreen(root: AccessibilityNodeInfo): Boolean {
        val shelfViewIds = listOf(
            "com.google.android.youtube:id/reel_shelf",
            "com.google.android.youtube:id/shorts_shelf",
            "com.google.android.youtube:id/reel_shelf_recycler_view",
            "com.google.android.youtube:id/reel_shelf_item",
            "com.google.android.youtube:id/reel_item_layout",
            "com.google.android.youtube:id/shorts_shelf_cell",
            "com.google.android.youtube:id/reel_carousel"
        )

        val rect = Rect()
        for (id in shelfViewIds) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (!nodes.isNullOrEmpty()) {
                for (node in nodes) {
                    if (node.isVisibleToUser) {
                        node.getBoundsInScreen(rect)
                        if (rect.height() >= 250 && rect.width() >= 150) {
                            nodes.forEach { it.recycle() }
                            return true
                        }
                    }
                }
                nodes.forEach { it.recycle() }
            }
        }

        // Also detect "Shorts" header on the feed shelf when visible on screen
        val headerNodes = root.findAccessibilityNodeInfosByText("Shorts")
        if (!headerNodes.isNullOrEmpty()) {
            val displayMetrics = resources.displayMetrics
            for (node in headerNodes) {
                if (node.isVisibleToUser) {
                    node.getBoundsInScreen(rect)
                    val resId = node.viewIdResourceName?.lowercase(Locale.US) ?: ""
                    val isFeedShelfHeader = resId.contains("title") || resId.contains("header") ||
                                           resId.contains("shelf") ||
                                           (rect.top > 150 && rect.bottom < displayMetrics.heightPixels - 180)
                    if (isFeedShelfHeader && !node.isSelected && node.parent?.isSelected != true) {
                        headerNodes.forEach { it.recycle() }
                        return true
                    }
                }
            }
            headerNodes.forEach { it.recycle() }
        }

        return false
    }

    private fun scanForShortsIndicators(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 30) return false
        if (!node.isVisibleToUser) return false

        val resId = node.viewIdResourceName
        if (resId != null) {
            val lowerId = resId.lowercase(Locale.US)
            val isNavOrShelf = lowerId.contains("shelf") || lowerId.contains("pivot") || lowerId.contains("tab") || lowerId.contains("carousel") || lowerId.contains("tray")
            if (!isNavOrShelf) {
                if (lowerId.contains("reel_player_page_view") ||
                    lowerId.contains("shorts_player_view") ||
                    lowerId.contains("shorts_view_pager") ||
                    lowerId.contains("reel_watch_fragment")) {
                    val rect = Rect()
                    node.getBoundsInScreen(rect)
                    if (rect.height() >= 500) {
                        return true
                    }
                }
            }
        }

        val desc = node.contentDescription?.toString()
        if (desc != null) {
            val lowerDesc = desc.lowercase(Locale.US)
            if (lowerDesc.contains("remix this short") ||
                lowerDesc.contains("dislike this short") ||
                lowerDesc.contains("sound used in this short") ||
                lowerDesc.contains("create a short using")) {
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

    private fun handleSnapchatEvent(event: AccessibilityEvent) {
        val rootNode = rootInActiveWindow
        if (rootNode != null) {
            try {
                isInsideSpotlight = detectSnapchatSpotlightPresence(rootNode)
            } finally {
                rootNode.recycle()
            }
        }

        if (isInsideSpotlight) {
            val now = System.currentTimeMillis()
            val isShortFormLocked = prefs.youtubeLockUntilTimestamp > now ||
                (prefs.shortsUsedSecondsToday >= prefs.shortsLimitMinutes * 60)

            if (isShortFormLocked) {
                if (!canTriggerLockAction()) return
                Log.d(TAG, "Snapchat Spotlight active during short-form lockout! Ejecting...")
                destroyBackgroundMediaAndPlayer(SNAPCHAT_PACKAGE)
                OverlayLockActivity.start(
                    this,
                    OverlayLockActivity.REASON_SHORTS_LIMIT,
                    targetPackage = SNAPCHAT_PACKAGE
                )
            }
        }
    }

    private fun handlePureShortFormEvent(event: AccessibilityEvent, pkgName: String) {
        isInsidePureShortForm = true

        // Kids Mode: 0-second tolerance for all pure short-form clones (ShareChat, Moj, Josh)
        if (prefs.isKidsModeEnabled) {
            if (!canTriggerLockAction()) return
            Log.d(TAG, "Kids Mode: Pure short-form app $pkgName 0s lockout! Showing lock overlay...")
            destroyBackgroundMediaAndPlayer(pkgName)
            dismissPictureInPictureIfPresent()
            OverlayLockActivity.start(
                this,
                OverlayLockActivity.REASON_KIDS_SHORTS_BLOCKED,
                targetPackage = pkgName
            )
            return
        }

        val now = System.currentTimeMillis()
        val isShortFormLocked = prefs.youtubeLockUntilTimestamp > now ||
            (prefs.shortsUsedSecondsToday >= prefs.shortsLimitMinutes * 60)

        if (isShortFormLocked) {
            if (!canTriggerLockAction()) return
            Log.d(TAG, "Pure short-form app $pkgName active during lockout! Showing lock overlay...")
            destroyBackgroundMediaAndPlayer(pkgName)
            dismissPictureInPictureIfPresent()
            OverlayLockActivity.start(
                this,
                OverlayLockActivity.REASON_SHORTS_LIMIT,
                targetPackage = pkgName
            )
        }
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

        // 0. Soft Search Immunity: Typing search queries, viewing suggestions,
        // or scrolling search results lists must NEVER trigger channel lockout!
        if (isSearchOrBrowseFeedActive(root)) return

        // Only enforce channel blocking when actively playing a video (watch player active) or inside Shorts
        val isWatchingVideo = isWatchPlayerActive(root) || isInsideShorts
        if (!isWatchingVideo) return

        for (rawBlocked in blockedList) {
            val blocked = rawBlocked.trim().removePrefix("@").lowercase(Locale.US)
            if (blocked.isEmpty()) continue

            // 1. Text & ContentDescription search: matches channel handles (@Firstpost),
            // avatars, subscribe buttons ("Subscribe to Firstpost"), or metadata lines
            val matches = root.findAccessibilityNodeInfosByText(blocked)
            if (!matches.isNullOrEmpty()) {
                for (node in matches) {
                    if (node.isVisibleToUser) {
                        val resId = node.viewIdResourceName?.lowercase(Locale.US) ?: ""
                        if (!resId.contains("comment")) {
                            val text = (node.text?.toString() ?: "").lowercase(Locale.US)
                            val desc = (node.contentDescription?.toString() ?: "").lowercase(Locale.US)

                            val isChannelIdentifier = resId.contains("channel") ||
                                    resId.contains("owner") ||
                                    resId.contains("byline") ||
                                    resId.contains("metadata") ||
                                    resId.contains("sub") ||
                                    resId.contains("avatar") ||
                                    text.startsWith("@$blocked") ||
                                    text.contains("@$blocked") ||
                                    text == blocked ||
                                    desc.contains("subscribe to $blocked") ||
                                    desc.contains("go to channel $blocked") ||
                                    desc.contains(blocked)

                            if (isChannelIdentifier) {
                                triggerChannelLock(rawBlocked)
                                matches.forEach { it.recycle() }
                                return
                            }
                        }
                    }
                }
                matches.forEach { it.recycle() }
            }

            // 2. Direct view ID search across known YouTube channel layout IDs
            for (id in channelNameViewIds) {
                val nodes = root.findAccessibilityNodeInfosByViewId(id)
                if (!nodes.isNullOrEmpty()) {
                    for (node in nodes) {
                        val text = node.text?.toString()?.trim()?.lowercase(Locale.US) ?: ""
                        val desc = node.contentDescription?.toString()?.trim()?.lowercase(Locale.US) ?: ""
                        if (text.contains(blocked) || desc.contains(blocked)) {
                            triggerChannelLock(rawBlocked)
                            nodes.forEach { it.recycle() }
                            return
                        }
                    }
                    nodes.forEach { it.recycle() }
                }
            }
        }
    }

    private fun triggerChannelLock(channelName: String) {
        if (!canTriggerLockAction()) return
        Log.w(TAG, "Blocked channel detected: $channelName! Showing smooth lock overlay...")
        destroyBackgroundMediaAndPlayer(YOUTUBE_PACKAGE)
        dismissPictureInPictureIfPresent()
        OverlayLockActivity.start(
            this,
            OverlayLockActivity.REASON_CHANNEL_BLOCKED,
            channelName,
            YOUTUBE_PACKAGE
        )
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

        if (windowPkg == YOUTUBE_PACKAGE && prefs.isShortFormMonitored(YOUTUBE_PACKAGE)) {
            activePackage = YOUTUBE_PACKAGE
            isInsideReels = false
            isInsideSpotlight = false
            isInsidePureShortForm = false
            if (rootNode != null) {
                try {
                    isInsideShorts = detectShortsPresence(rootNode)
                    checkAndBlockRestrictedChannels(rootNode)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in YouTube periodic tick: ${e.message}")
                }
            }

            if (prefs.isKidsModeEnabled) {
                val isYtLocked = prefs.youtubeLockUntilTimestamp > now ||
                    (prefs.shortsUsedSecondsToday >= prefs.shortsLimitMinutes * 60)
                if (isYtLocked && canTriggerLockAction()) {
                    Log.w(TAG, "Periodic tick: Kids Mode active and YouTube limit reached! Ejecting...")
                    destroyBackgroundMediaAndPlayer(YOUTUBE_PACKAGE)
                    dismissPictureInPictureIfPresent()
                    OverlayLockActivity.start(this, OverlayLockActivity.REASON_YOUTUBE_LOCKED, targetPackage = YOUTUBE_PACKAGE)
                }
            }
        } else if (windowPkg == INSTAGRAM_PACKAGE && prefs.isShortFormMonitored(INSTAGRAM_PACKAGE)) {
            activePackage = INSTAGRAM_PACKAGE
            isInsideShorts = false
            isInsideReels = true
            isInsideSpotlight = false
            isInsidePureShortForm = false

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
        } else if (windowPkg == SNAPCHAT_PACKAGE && prefs.isShortFormMonitored(SNAPCHAT_PACKAGE)) {
            activePackage = SNAPCHAT_PACKAGE
            isInsideShorts = false
            isInsideReels = false
            isInsidePureShortForm = false
            if (rootNode != null) {
                try {
                    isInsideSpotlight = detectSnapchatSpotlightPresence(rootNode)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in Snapchat periodic tick: ${e.message}")
                }
            }
            if (isInsideSpotlight) {
                val isShortFormLocked = prefs.youtubeLockUntilTimestamp > now ||
                    (prefs.shortsUsedSecondsToday >= prefs.shortsLimitMinutes * 60)
                if (isShortFormLocked && canTriggerLockAction()) {
                    destroyBackgroundMediaAndPlayer(SNAPCHAT_PACKAGE)
                    OverlayLockActivity.start(
                        this,
                        OverlayLockActivity.REASON_SHORTS_LIMIT,
                        targetPackage = SNAPCHAT_PACKAGE
                    )
                }
            }
        } else if (windowPkg != null && isPureShortFormPackage(windowPkg) && prefs.isShortFormMonitored(windowPkg)) {
            activePackage = windowPkg
            isInsideShorts = false
            isInsideReels = false
            isInsideSpotlight = false
            isInsidePureShortForm = true
            val isShortFormLocked = prefs.youtubeLockUntilTimestamp > now ||
                (prefs.shortsUsedSecondsToday >= prefs.shortsLimitMinutes * 60)
            if (isShortFormLocked && canTriggerLockAction()) {
                destroyBackgroundMediaAndPlayer(windowPkg)
                dismissPictureInPictureIfPresent()
                OverlayLockActivity.start(
                    this,
                    OverlayLockActivity.REASON_SHORTS_LIMIT,
                    targetPackage = windowPkg
                )
            }
        } else {
            isInsideShorts = false
            isInsideReels = false
            isInsideSpotlight = false
            isInsidePureShortForm = false
        }

        // 1. Screen Time Tracking
        if (prefs.isKidsModeEnabled) {
            // Kids Mode: Only long-form YouTube increments screen time (Shorts is ejected with 0s tolerance)
            if (activePackage == YOUTUBE_PACKAGE) {
                prefs.addShortsUsedSeconds(deltaSeconds)
                val usedSec = prefs.shortsUsedSecondsToday
                val limitSec = prefs.shortsLimitMinutes * 60
                if (usedSec >= limitSec) {
                    if (canTriggerLockAction()) {
                        Log.w(TAG, "Kids Mode: Long-form YouTube limit reached ($usedSec >= $limitSec s)! Setting 30m cooldown...")
                        prefs.youtubeLockUntilTimestamp = now + 30 * 60 * 1000L
                        destroyBackgroundMediaAndPlayer(YOUTUBE_PACKAGE)
                        dismissPictureInPictureIfPresent()
                        OverlayLockActivity.start(this, OverlayLockActivity.REASON_YOUTUBE_LOCKED, targetPackage = YOUTUBE_PACKAGE)
                    }
                }
            }
        } else {
            // Adult Focus Mode: Unified short-form tracking
            val isShortFormActive = (activePackage == YOUTUBE_PACKAGE && isInsideShorts) ||
                                    (activePackage == INSTAGRAM_PACKAGE && isInsideReels) ||
                                    (activePackage == SNAPCHAT_PACKAGE && isInsideSpotlight) ||
                                    (isInsidePureShortForm)

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
                    OverlayLockActivity.start(this, OverlayLockActivity.REASON_SHORTS_LIMIT, targetPackage = targetPkg)
                    isInsideShorts = false
                    isInsideReels = false
                    isInsideSpotlight = false
                    isInsidePureShortForm = false
                }
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
                lower.contains("facebook") ||
                lower.contains("twitter") ||
                lower.contains("x.android") ||
                lower.contains("reddit") ||
                lower.contains("sharechat") ||
                lower.contains("mohalla") ||
                lower.contains("eterno") ||
                lower.contains("josh")
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
