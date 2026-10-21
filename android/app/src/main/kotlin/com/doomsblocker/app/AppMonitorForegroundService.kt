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
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

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
    private val handler = Handler(Looper.getMainLooper())
    private var lastCheckTime = System.currentTimeMillis()

    private val monitorRunnable = object : Runnable {
        override fun run() {
            checkForegroundAppAndEnforceRules()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = AppPreferences(applicationContext)
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        lastCheckTime = System.currentTimeMillis()
        handler.post(monitorRunnable)
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

        // 1. YouTube 30-minute lock check
        if (fgPackage == "com.google.android.youtube" && prefs.isYouTubeLocked) {
            Log.w(TAG, "YouTube opened during active lock window! Ejecting...")
            ejectToHome()
            OverlayLockActivity.start(this, OverlayLockActivity.REASON_YOUTUBE_LOCKED)
            return
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
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
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

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DoomsBlocker Guard Active")
            .setContentText("Shorts limit (2m) & Nephew mode active")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(monitorRunnable)
    }
}
