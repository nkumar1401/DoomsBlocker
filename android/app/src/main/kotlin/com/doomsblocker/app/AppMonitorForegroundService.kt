package com.doomsblocker.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.util.Locale

class AppMonitorForegroundService : Service() {

    companion object {
        private const val TAG = "AppMonitorService"
        private const val CHANNEL_ID = "doomsblocker_monitor_channel"
        private const val NOTIFICATION_ID = 1001

        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context) {
            val intent = Intent(context, AppMonitorForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, AppMonitorForegroundService::class.java)
            context.stopService(intent)
        }
    }

    private lateinit var prefs: AppPreferences
    private lateinit var notificationManager: NotificationManager
    private val handler = Handler(Looper.getMainLooper())
    private var lastCheckTime = System.currentTimeMillis()
    private var lastNotifTimeSec = -1
    private var lastNotifLocked = false
    private var lastNotifStudyZone = false
    private var lastKnownForegroundPkg: String? = null
    private var lastLockActionTimeMillis = 0L

    private fun canTriggerLockAction(): Boolean {
        val now = System.currentTimeMillis()
        if (now - lastLockActionTimeMillis < 2500L) {
            return false
        }
        lastLockActionTimeMillis = now
        return true
    }

    private fun checkAndAutoRestrictInstalledPackage(installedPkg: String) {
        if (!prefs.isAutoRestrictGamesEnabled) return
        if (prefs.exemptedGames.contains(installedPkg) || prefs.restrictedApps.contains(installedPkg)) return
        if (GameDetector.isPackageGame(applicationContext, installedPkg, null, prefs)) {
            val added = prefs.autoRestrictGameIfEligible(installedPkg, true)
            if (added) {
                Log.i(TAG, "Auto-restricted newly installed game: $installedPkg")
            }
        }
    }

    private val packageInstallReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            if (action == Intent.ACTION_PACKAGE_ADDED || action == Intent.ACTION_PACKAGE_REPLACED) {
                val installedPkg = intent.data?.schemeSpecificPart ?: return
                if (installedPkg == packageName) return
                GameDetector.invalidateCache(installedPkg)
                prefs.lastPlayStoreInstallTimestamp = System.currentTimeMillis()
                checkAndAutoRestrictInstalledPackage(installedPkg)

                // Re-check asynchronously in case Play Store's setApplicationCategoryHint() arrives after install commit
                val recheckDelaysMs = longArrayOf(3_000L, 10_000L, 30_000L)
                for (delayMs in recheckDelaysMs) {
                    handler.postDelayed({
                        GameDetector.invalidateCache(installedPkg)
                        checkAndAutoRestrictInstalledPackage(installedPkg)
                    }, delayMs)
                }
            }
        }
    }

    private val monitorRunnable = object : Runnable {
        override fun run() {
            checkForegroundAppAndEnforceRules()
            updateNotificationDynamic()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        prefs = AppPreferences(applicationContext)
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        GameDetector.syncAllInstalledGames(this, prefs)
        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_PACKAGE_ADDED)
                addAction(Intent.ACTION_PACKAGE_REPLACED)
                addDataScheme("package")
            }
            ContextCompat.registerReceiver(this, packageInstallReceiver, filter, ContextCompat.RECEIVER_EXPORTED)
        } catch (e: Exception) {
            Log.e(TAG, "Error registering packageInstallReceiver: ${e.message}")
        }
        lastCheckTime = System.currentTimeMillis()
        handler.post(monitorRunnable)
    }

    private fun updateNotificationDynamic() {
        val isStudyZone = prefs.isStudyZoneActive
        val isLocked = prefs.isYouTubeLocked || isStudyZone
        val remainingSec = if (isStudyZone) {
            ((prefs.studyZoneExpireTimestamp - System.currentTimeMillis()) / 1000).toInt().coerceAtLeast(0)
        } else if (prefs.isYouTubeLocked) {
            ((prefs.youtubeLockUntilTimestamp - System.currentTimeMillis()) / 1000).toInt().coerceAtLeast(0)
        } else {
            prefs.shortsUsedSecondsToday
        }

        if (isLocked != lastNotifLocked || isStudyZone != lastNotifStudyZone || remainingSec != lastNotifTimeSec) {
            lastNotifLocked = isLocked
            lastNotifStudyZone = isStudyZone
            lastNotifTimeSec = remainingSec
            try {
                notificationManager.notify(NOTIFICATION_ID, buildNotification())
            } catch (e: Exception) {
                Log.e(TAG, "Error updating notification: ${e.message}")
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun checkForegroundAppAndEnforceRules() {
        val now = System.currentTimeMillis()
        val deltaSeconds = ((now - lastCheckTime) / 1000).toInt().coerceIn(0, 5)
        lastCheckTime = now

        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        if (powerManager != null && !powerManager.isInteractive) {
            return
        }

        val fgPackage = getForegroundPackage(now) ?: return
        if (fgPackage == packageName || GameDetector.isPaymentOrBankingApp(fgPackage)) {
            return
        }

        // 1. YouTube lock check
        if (fgPackage == "com.google.android.youtube") {
            if (prefs.isKidsModeEnabled && prefs.youtubeLockUntilTimestamp > 0L && now >= prefs.youtubeLockUntilTimestamp) {
                // Cooldown period expired! Reset usage
                prefs.youtubeLockUntilTimestamp = 0L
                prefs.shortsUsedSecondsToday = 0
            }
            if (prefs.isYouTubeLocked) {
                if (prefs.isKidsModeEnabled) {
                    if (canTriggerLockAction()) {
                        Log.w(TAG, "Kids Mode active: YouTube opened during active lock window! Ejecting...")
                        ejectToHome()
                        OverlayLockActivity.start(this, OverlayLockActivity.REASON_YOUTUBE_LOCKED)
                    }
                    return
                }
                // In Adult Mode, normal YouTube app & longform video are permitted; Shorts is strictly blocked by AccessibilityService!
            }
        }

        // 1.1 Kids Mode Social Media 24/7 Block
        if (prefs.isKidsModeEnabled && isSocialOrDistractionApp(fgPackage)) {
            if (canTriggerLockAction()) {
                Log.w(TAG, "Kids Mode active: Social app $fgPackage is blocked 24/7!")
                ejectToHome(fgPackage)
                OverlayLockActivity.start(
                    this,
                    OverlayLockActivity.REASON_KIDS_SOCIAL_BLOCKED,
                    targetPackage = fgPackage
                )
            }
            return
        }

        // 2. Study Zone distraction apps check
        if (prefs.isStudyZoneActive && isSocialOrDistractionApp(fgPackage)) {
            if (canTriggerLockAction()) {
                Log.w(TAG, "Study Zone Active: Distraction app $fgPackage blocked during study hours!")
                ejectToHome(fgPackage)
                OverlayLockActivity.start(
                    this,
                    OverlayLockActivity.REASON_STUDY_ZONE,
                    prefs.studyZoneName,
                    fgPackage
                )
            }
            return
        }

        // 3. Restricted apps & games check (strictly scoped to Kids Mode or Study Zone)
        val isGameEnforcementActive = prefs.isKidsModeEnabled || prefs.isStudyZoneActive
        if (isGameEnforcementActive && GameDetector.syncAndCheckRestricted(this, prefs, fgPackage, null)) {
            if (prefs.isStudyZoneActive) {
                if (canTriggerLockAction()) {
                    Log.w(TAG, "Study Zone Active: Restricted game $fgPackage blocked during study hours!")
                    ejectToHome(fgPackage)
                    OverlayLockActivity.start(
                        this,
                        OverlayLockActivity.REASON_STUDY_ZONE,
                        prefs.studyZoneName,
                        fgPackage
                    )
                }
                return
            }

            if (deltaSeconds > 0) {
                prefs.addAppUsageSeconds(fgPackage, deltaSeconds)
            }

            val appUsedSeconds = prefs.getAppUsageSeconds(fgPackage)
            val totalUsedSeconds = prefs.getTotalRestrictedAppsUsageSeconds()
            val limitSeconds = prefs.gameLimitMinutes * 60

            if (totalUsedSeconds >= limitSeconds || appUsedSeconds >= limitSeconds) {
                if (canTriggerLockAction()) {
                    Log.w(TAG, "Restricted game limit reached ($appUsedSeconds s used / $totalUsedSeconds s total / $limitSeconds s limit). Ejecting and showing lock overlay...")
                    ejectToHome(fgPackage)
                    OverlayLockActivity.start(
                        this,
                        OverlayLockActivity.REASON_GAME_LIMIT,
                        getAppLabel(fgPackage),
                        fgPackage
                    )
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

    private fun getForegroundPackage(now: Long): String? {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return lastKnownForegroundPkg
        val lookbackMs = if (lastKnownForegroundPkg == null) 60_000L else 10_000L
        val events = usageStatsManager.queryEvents(now - lookbackMs, now) ?: return lastKnownForegroundPkg
        val event = UsageEvents.Event()
        var latestResumedPkg: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                val pkg = event.packageName
                if (!pkg.isNullOrBlank() && pkg != "com.android.systemui") {
                    latestResumedPkg = pkg
                }
            }
        }
        if (latestResumedPkg != null) {
            lastKnownForegroundPkg = latestResumedPkg
        }
        return lastKnownForegroundPkg
    }

    private fun ejectToHome(pkgToKill: String? = null) {
        lastKnownForegroundPkg = null
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
            audioManager?.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, android.view.KeyEvent.KEYCODE_MEDIA_PAUSE))
            audioManager?.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, android.view.KeyEvent.KEYCODE_MEDIA_PAUSE))
        } catch (e: Exception) {
            Log.e(TAG, "Error pausing audio: ${e.message}")
        }

        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? android.app.ActivityManager
            val target = pkgToKill ?: "com.google.android.youtube"
            am?.killBackgroundProcesses(target)
            if (target != "com.google.android.youtube") {
                am?.killBackgroundProcesses("com.google.android.youtube")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error killing background process: ${e.message}")
        }

        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        startActivity(homeIntent)
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

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "DoomsBlocker Active Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors Shorts and game limits in background"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val isStudyZone = prefs.isStudyZoneActive
        val isLocked = prefs.isYouTubeLocked || isStudyZone
        val smallIcon = if (isLocked) R.drawable.ic_notification_locked else R.drawable.ic_notification_unlocked

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(smallIcon)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        if (isStudyZone) {
            val expire = prefs.studyZoneExpireTimestamp
            val remainingSec = ((expire - System.currentTimeMillis()) / 1000).toInt().coerceAtLeast(0)
            val hours = remainingSec / 3600
            val minutes = (remainingSec % 3600) / 60
            val seconds = remainingSec % 60
            val timeFormatted = if (hours > 0) {
                String.format(Locale.US, "%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                String.format(Locale.US, "%02d:%02d", minutes, seconds)
            }

            builder
                .setContentTitle("📚 Study Zone: ${prefs.studyZoneName} • $timeFormatted")
                .setContentText("Focus session in progress • $timeFormatted remaining (Distractions locked)")
                .setStyle(NotificationCompat.BigTextStyle().bigText("Focus session at ${prefs.studyZoneName}.\nTime remaining: $timeFormatted.\nInstagram, Shorts, and Games are locked until session finishes."))
                .setColor(Color.parseColor("#06B6D4"))
                .addAction(android.R.drawable.ic_menu_preferences, "Study Dashboard", pendingIntent)
        } else if (prefs.isYouTubeLocked) {
            val remainingMillis = prefs.youtubeLockUntilTimestamp - System.currentTimeMillis()
            val remainingSec = (remainingMillis / 1000).toInt().coerceAtLeast(0)
            val minutes = remainingSec / 60
            val seconds = remainingSec % 60
            val timeFormatted = String.format(Locale.US, "%02d:%02d", minutes, seconds)
            val totalLockoutSec = prefs.shortsLockDurationMinutes * 60

            val unlockIntent = Intent(this, OverlayLockActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(OverlayLockActivity.EXTRA_REASON, OverlayLockActivity.REASON_YOUTUBE_LOCKED)
            }
            val unlockPendingIntent = PendingIntent.getActivity(
                this,
                1,
                unlockIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            builder
                .setContentTitle("YouTube Shorts & Reels Locked • $timeFormatted remaining")
                .setContentText("Locked for ${prefs.shortsLockDurationMinutes}m after reaching limit")
                .setProgress(totalLockoutSec, remainingSec, false)
                .setColor(Color.parseColor("#EF4444"))
                .addAction(android.R.drawable.ic_lock_idle_lock, "PIN Override", unlockPendingIntent)
                .addAction(android.R.drawable.ic_menu_preferences, "Open App", pendingIntent)
        } else {
            val usedSec = prefs.shortsUsedSecondsToday
            val limitSec = prefs.shortsLimitMinutes * 60
            val usedFormatted = String.format(Locale.US, "%02d:%02d", usedSec / 60, usedSec % 60)
            val limitFormatted = String.format(Locale.US, "%02d:%02d", limitSec / 60, limitSec % 60)

            val modeText = if (prefs.isKidsModeEnabled) {
                "Kids Mode ON • Strict child protection active"
            } else {
                "Adult Mode • Shorts & Reels limit: ${prefs.shortsLimitMinutes} min"
            }

            builder
                .setContentTitle("DoomsBlocker Active • Shorts: $usedFormatted / $limitFormatted")
                .setContentText(modeText)
                .setProgress(limitSec, usedSec, false)
                .setColor(Color.parseColor("#06B6D4"))
                .addAction(android.R.drawable.ic_menu_preferences, "Dashboard", pendingIntent)
        }

        return builder.build()
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        handler.removeCallbacksAndMessages(null)
        try {
            unregisterReceiver(packageInstallReceiver)
        } catch (_: Exception) {}
    }
}
