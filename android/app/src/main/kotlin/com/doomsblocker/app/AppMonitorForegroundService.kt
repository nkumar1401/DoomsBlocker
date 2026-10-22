package com.doomsblocker.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Locale

class AppMonitorForegroundService : Service() {

    companion object {
        private const val TAG = "AppMonitorService"
        private const val CHANNEL_ID = "doomsblocker_monitor_channel"
        private const val NOTIFICATION_ID = 1001

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

    private val monitorRunnable = object : Runnable {
        override fun run() {
            checkForegroundAppAndEnforceRules()
            updateNotificationDynamic()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = AppPreferences(applicationContext)
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        lastCheckTime = System.currentTimeMillis()
        handler.post(monitorRunnable)
    }

    private fun updateNotificationDynamic() {
        val isLocked = prefs.isYouTubeLocked
        val remainingSec = if (isLocked) {
            ((prefs.youtubeLockUntilTimestamp - System.currentTimeMillis()) / 1000).toInt().coerceAtLeast(0)
        } else {
            prefs.shortsUsedSecondsToday
        }

        if (isLocked != lastNotifLocked || remainingSec != lastNotifTimeSec) {
            lastNotifLocked = isLocked
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

        val fgPackage = getForegroundPackage(now) ?: return

        // 1. YouTube lock check
        if (fgPackage == "com.google.android.youtube" && prefs.isYouTubeLocked) {
            if (prefs.isNephewModeEnabled) {
                Log.w(TAG, "Nephew Mode active: YouTube opened during active lock window! Ejecting...")
                ejectToHome()
                OverlayLockActivity.start(this, OverlayLockActivity.REASON_YOUTUBE_LOCKED)
                return
            }
            // In Adult Mode, normal YouTube app & longform video are permitted; Shorts is strictly blocked by AccessibilityService!
        }

        // 2. Nephew Mode restricted games check
        if (prefs.isNephewModeEnabled && prefs.restrictedApps.contains(fgPackage)) {
            if (deltaSeconds > 0) {
                prefs.addAppUsageSeconds(fgPackage, deltaSeconds)
            }

            val totalUsedSeconds = prefs.getTotalRestrictedAppsUsageSeconds()
            val limitSeconds = prefs.gameLimitMinutes * 60

            if (totalUsedSeconds >= limitSeconds) {
                Log.w(TAG, "Combined game limit reached ($totalUsedSeconds >= $limitSeconds s). Locking...")
                ejectToHome()
                OverlayLockActivity.start(
                    this,
                    OverlayLockActivity.REASON_GAME_LIMIT,
                    getAppLabel(fgPackage)
                )
            }
        }
    }

    private fun getForegroundPackage(now: Long): String? {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return null
        val events = usageStatsManager.queryEvents(now - 3000, now) ?: return null
        val event = UsageEvents.Event()
        var fgPkg: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                fgPkg = event.packageName
            }
        }
        return fgPkg
    }

    private fun ejectToHome() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
            audioManager?.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, android.view.KeyEvent.KEYCODE_MEDIA_PAUSE))
            audioManager?.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, android.view.KeyEvent.KEYCODE_MEDIA_PAUSE))
        } catch (e: Exception) {
            Log.e(TAG, "Error pausing audio: ${e.message}")
        }

        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? android.app.ActivityManager
            am?.killBackgroundProcesses("com.google.android.youtube")
        } catch (e: Exception) {
            Log.e(TAG, "Error killing background YouTube process: ${e.message}")
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

        val isLocked = prefs.isYouTubeLocked
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        if (isLocked) {
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
                .setContentTitle("YouTube Shorts Locked • $timeFormatted remaining")
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

            val modeText = if (prefs.isNephewModeEnabled) {
                "Nephew Guard ON • Strict child protection active"
            } else {
                "Adult Mode • Shorts restricted to ${prefs.shortsLimitMinutes} min"
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
        handler.removeCallbacks(monitorRunnable)
    }
}
