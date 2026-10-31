package com.doomsblocker.app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import androidx.core.app.NotificationCompat
import android.app.Activity
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.doomsblocker.app/control"
    private lateinit var prefs: AppPreferences
    private lateinit var appUpdateManager: AppUpdateManager
    private val REQUEST_CODE_IMMEDIATE_UPDATE = 9001
    private val REQUEST_CODE_DEVICE_CREDENTIAL = 9002
    private val REQUEST_CODE_NOTIFICATION = 9003
    private var pendingAuthResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        prefs = AppPreferences(applicationContext)
        appUpdateManager = AppUpdateManagerFactory.create(this)

        // Start background monitor service
        try {
            AppMonitorForegroundService.start(this)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDashboardData" -> {
                    val now = System.currentTimeMillis()
                    val remainingLockSec = if (prefs.isYouTubeLocked) {
                        ((prefs.youtubeLockUntilTimestamp - now) / 1000).toInt().coerceAtLeast(0)
                    } else 0

                    val data = mapOf(
                        "shortsLimitMinutes" to prefs.shortsLimitMinutes,
                        "shortsLockDurationMinutes" to prefs.shortsLockDurationMinutes,
                        "shortsUsedSecondsToday" to prefs.shortsUsedSecondsToday,
                        "isYouTubeLocked" to prefs.isYouTubeLocked,
                        "youtubeLockRemainingSeconds" to remainingLockSec,
                        "isNephewModeEnabled" to prefs.isNephewModeEnabled,
                        "isKidsModeEnabled" to prefs.isKidsModeEnabled,
                        "enabledShortFormApps" to prefs.enabledShortFormApps.toList(),
                        "gameLimitMinutes" to prefs.gameLimitMinutes,
                        "restrictedAppsCount" to prefs.restrictedApps.size,
                        "blockedChannelsCount" to prefs.blockedChannels.size,
                        "isStudyZoneActive" to prefs.isStudyZoneActive,
                        "studyZoneName" to prefs.studyZoneName,
                        "studyZoneRemainingSeconds" to prefs.studyZoneRemainingSeconds,
                        "isPinSet" to prefs.isPinSet
                    )
                    result.success(data)
                }

                "updateShortsConfig" -> {
                    val limit = call.argument<Int>("limitMinutes") ?: 2
                    val lockDuration = call.argument<Int>("lockDurationMinutes") ?: 30
                    prefs.shortsLimitMinutes = limit
                    prefs.shortsLockDurationMinutes = lockDuration
                    result.success(true)
                }

                "setNephewMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val pin = call.argument<String>("pin")
                    if (pin != null && pin.isNotEmpty()) {
                        prefs.parentPin = pin
                    }
                    prefs.isNephewModeEnabled = enabled
                    result.success(true)
                }

                "setKidsMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val pin = call.argument<String>("pin")
                    if (pin != null && pin.isNotEmpty()) {
                        prefs.parentPin = pin
                    }
                    prefs.isKidsModeEnabled = enabled
                    result.success(true)
                }

                "getEnabledShortFormApps" -> {
                    result.success(prefs.enabledShortFormApps.toList())
                }

                "setEnabledShortFormApps" -> {
                    val packages = call.argument<List<String>>("packages") ?: listOf(
                        AppPreferences.PKG_YOUTUBE,
                        AppPreferences.PKG_INSTAGRAM
                    )
                    prefs.enabledShortFormApps = packages.toSet()
                    result.success(true)
                }

                "checkInAppUpdate" -> {
                    try {
                        val appUpdateInfoTask = appUpdateManager.appUpdateInfo
                        appUpdateInfoTask.addOnSuccessListener { appUpdateInfo ->
                            val isAvailable = appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
                            val isImmediateAllowed = appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)
                            val availableVersionCode = appUpdateInfo.availableVersionCode()
                            val priority = appUpdateInfo.updatePriority()

                            result.success(mapOf(
                                "hasUpdate" to isAvailable,
                                "isImmediateAllowed" to isImmediateAllowed,
                                "availableVersionCode" to availableVersionCode,
                                "priority" to priority
                            ))
                        }.addOnFailureListener { e ->
                            Log.d("MainActivity", "InAppUpdate check failed (sideload/dev): ${e.message}")
                            result.success(mapOf(
                                "hasUpdate" to false,
                                "isImmediateAllowed" to false,
                                "availableVersionCode" to 0,
                                "error" to (e.message ?: "Unavailable")
                            ))
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error querying appUpdateManager: ${e.message}")
                        result.success(mapOf(
                            "hasUpdate" to false,
                            "isImmediateAllowed" to false,
                            "availableVersionCode" to 0,
                            "error" to (e.message ?: "Error")
                        ))
                    }
                }

                "startImmediateUpdate" -> {
                    try {
                        val appUpdateInfoTask = appUpdateManager.appUpdateInfo
                        appUpdateInfoTask.addOnSuccessListener { appUpdateInfo ->
                            if (appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                                appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)
                            ) {
                                try {
                                    appUpdateManager.startUpdateFlowForResult(
                                        appUpdateInfo,
                                        AppUpdateType.IMMEDIATE,
                                        this,
                                        REQUEST_CODE_IMMEDIATE_UPDATE
                                    )
                                    result.success(true)
                                } catch (e: Exception) {
                                    Log.e("MainActivity", "Failed to start update flow: ${e.message}")
                                    result.success(false)
                                }
                            } else {
                                result.success(false)
                            }
                        }.addOnFailureListener {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Exception starting immediate update: ${e.message}")
                        result.success(false)
                    }
                }

                "setGameLimitMinutes" -> {
                    val minutes = call.argument<Int>("minutes") ?: 20
                    prefs.gameLimitMinutes = minutes
                    result.success(true)
                }

                "getInstalledApps" -> {
                    val appsList = getInstalledLaunchableApps()
                    result.success(appsList)
                }

                "toggleRestrictedApp" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg != null) {
                        val current = prefs.restrictedApps.toMutableSet()
                        if (current.contains(pkg)) {
                            current.remove(pkg)
                        } else {
                            current.add(pkg)
                        }
                        prefs.restrictedApps = current
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Package name missing", null)
                    }
                }

                "getBlockedChannels" -> {
                    result.success(prefs.blockedChannels)
                }

                "addBlockedChannel" -> {
                    val channel = call.argument<String>("channel")
                    if (!channel.isNullOrBlank()) {
                        val current = prefs.blockedChannels.toMutableList()
                        if (!current.contains(channel.trim())) {
                            current.add(channel.trim())
                            prefs.blockedChannels = current
                        }
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Channel name missing", null)
                    }
                }

                "removeBlockedChannel" -> {
                    val channel = call.argument<String>("channel")
                    if (channel != null) {
                        val current = prefs.blockedChannels.toMutableList()
                        current.remove(channel.trim())
                        prefs.blockedChannels = current
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Channel name missing", null)
                    }
                }

                "isPinSet" -> {
                    result.success(prefs.isPinSet)
                }

                "setPin" -> {
                    val pin = call.argument<String>("pin")
                    if (!pin.isNullOrBlank() && pin.trim().length == 4) {
                        prefs.parentPin = pin.trim()
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "PIN must be 4 digits", null)
                    }
                }

                "verifyPin" -> {
                    val pin = call.argument<String>("pin") ?: ""
                    result.success(prefs.isPinSet && pin == prefs.parentPin)
                }

                "authenticateDeviceOwner" -> {
                    val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
                    if (keyguardManager.isDeviceSecure) {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            keyguardManager.createConfirmDeviceCredentialIntent(
                                "Parent Verification",
                                "Confirm your fingerprint or screen lock to verify Parent identity"
                            )
                        } else null

                        if (intent != null) {
                            pendingAuthResult = result
                            startActivityForResult(intent, REQUEST_CODE_DEVICE_CREDENTIAL)
                        } else {
                            result.success(false)
                        }
                    } else {
                        // Device has no screen lock, allow fallback
                        result.success(true)
                    }
                }

                "emergencyUnlockYouTube" -> {
                    val pin = call.argument<String>("pin") ?: ""
                    if (prefs.isPinSet && pin == prefs.parentPin) {
                        prefs.unlockYouTubeEmergency()
                        prefs.resetGamesUsageEmergency()
                        try {
                            val dismissIntent = Intent("com.doomsblocker.ACTION_DISMISS_OVERLAY")
                            dismissIntent.setPackage(packageName)
                            sendBroadcast(dismissIntent)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Error sending dismiss overlay broadcast: ${e.message}")
                        }
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }

                "startStudyZone" -> {
                    val zoneName = call.argument<String>("zoneName") ?: "Library Study Zone"
                    val durationMinutes = call.argument<Int>("durationMinutes") ?: 60
                    prefs.startStudyZone(zoneName, durationMinutes)
                    result.success(true)
                }

                "endStudyZone" -> {
                    prefs.endStudyZoneSession()
                    try {
                        val dismissIntent = Intent("com.doomsblocker.ACTION_DISMISS_OVERLAY")
                        dismissIntent.setPackage(packageName)
                        sendBroadcast(dismissIntent)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error sending dismiss overlay broadcast: ${e.message}")
                    }
                    result.success(true)
                }

                "checkPermissions" -> {
                    val permissions = mapOf(
                        "accessibility" to isAccessibilityServiceEnabled(),
                        "overlay" to isOverlayPermissionGranted(),
                        "usageStats" to isUsageStatsPermissionGranted(),
                        "notification" to isNotificationPermissionGranted()
                    )
                    result.success(permissions)
                }

                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE_NOTIFICATION)
                        }
                    }
                    result.success(true)
                }

                "showLocalNotification" -> {
                    val title = call.argument<String>("title") ?: "DoomsBlocker"
                    val body = call.argument<String>("body") ?: ""
                    val notificationId = call.argument<Int>("id") ?: 2002
                    showLocalReminderNotification(title, body, notificationId)
                    result.success(true)
                }

                "openAppDetailsSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }

                "openOverlaySettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(true)
                }

                "openUsageStatsSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                }

                "getDeviceManufacturer" -> {
                    result.success(Build.MANUFACTURER.lowercase())
                }

                "openBatteryOptimizationSettings" -> {
                    try {
                        val manufacturer = Build.MANUFACTURER.lowercase()
                        var launched = false

                        // Xiaomi / Redmi / Poco MIUI permission editor
                        if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco")) {
                            try {
                                val miuiIntent = Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                                    setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
                                    putExtra("extra_pkgname", packageName)
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(miuiIntent)
                                launched = true
                            } catch (_: Exception) {}
                        }

                        if (!launched) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                            } else {
                                val intent = Intent(Settings.ACTION_SETTINGS).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (err: Exception) {
                            result.error("INTENT_ERROR", err.message, null)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun getInstalledLaunchableApps(): List<Map<String, Any>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = pm.queryIntentActivities(intent, 0)
        val restricted = prefs.restrictedApps

        val systemBlacklist = setOf(
            "com.android.settings",
            "com.google.android.settings",
            "com.android.systemui",
            "com.android.vending",
            "com.google.android.googlequicksearchbox",
            "com.google.android.packageinstaller",
            "com.android.packageinstaller",
            "com.google.android.dialer",
            "com.android.dialer",
            "com.android.phone",
            "com.google.android.deskclock",
            "com.android.deskclock",
            "com.google.android.calculator",
            "com.android.calculator2",
            "com.google.android.contacts",
            "com.android.contacts",
            "com.google.android.apps.messaging",
            "com.android.mms",
            "com.android.camera",
            "com.google.android.GoogleCamera"
        )

        val list = mutableListOf<Map<String, Any>>()
        for (info in resolveInfos) {
            val pkg = info.activityInfo.packageName
            // Skip self and basic system framework
            if (pkg == packageName) continue
            if (systemBlacklist.contains(pkg) || pkg.startsWith("com.android.internal")) continue

            val appInfo = info.activityInfo.applicationInfo
            val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val isGame = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                appInfo.category == ApplicationInfo.CATEGORY_GAME || (appInfo.flags and ApplicationInfo.FLAG_IS_GAME) != 0
            } else {
                (appInfo.flags and ApplicationInfo.FLAG_IS_GAME) != 0
            }

            // Exclude system utilities unless it's a game or already restricted by user
            if (isSystem && !isGame && !restricted.contains(pkg)) {
                continue
            }

            val label = info.loadLabel(pm).toString()
            val usedSec = prefs.getAppUsageSeconds(pkg)
            val isRestricted = restricted.contains(pkg)

            list.add(
                mapOf(
                    "name" to label,
                    "packageName" to pkg,
                    "isRestricted" to isRestricted,
                    "usedMinutes" to (usedSec / 60),
                    "isGame" to isGame
                )
            )
        }
        return list.sortedWith(
            compareByDescending<Map<String, Any>> { it["isRestricted"] as Boolean }
                .thenByDescending { it["isGame"] as Boolean }
        )
    }

    private fun isNotificationPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
            nm?.areNotificationsEnabled() ?: true
        } else {
            true
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedService = "$packageName/${DoomsAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        return enabledServices.contains(expectedService) || enabledServices.contains(DoomsAccessibilityService::class.java.simpleName)
    }

    private fun isOverlayPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else true
    }

    private fun isUsageStatsPermissionGranted(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_IMMEDIATE_UPDATE) {
            if (resultCode != Activity.RESULT_OK) {
                Log.d("MainActivity", "Immediate update was cancelled or failed by user (resultCode=$resultCode)")
            }
        } else if (requestCode == REQUEST_CODE_DEVICE_CREDENTIAL) {
            val success = (resultCode == Activity.RESULT_OK)
            pendingAuthResult?.success(success)
            pendingAuthResult = null
        }
    }

    override fun onResume() {
        super.onResume()
        try {
            appUpdateManager.appUpdateInfo.addOnSuccessListener { appUpdateInfo ->
                if (appUpdateInfo.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
                    appUpdateManager.startUpdateFlowForResult(
                        appUpdateInfo,
                        AppUpdateType.IMMEDIATE,
                        this,
                        REQUEST_CODE_IMMEDIATE_UPDATE
                    )
                }
            }
        } catch (e: Exception) {
            // Sideloaded or Play Core not available
        }
    }

    private fun showLocalReminderNotification(title: String, body: String, notificationId: Int) {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "doomsblocker_reminders_channel"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "DoomsBlocker Reminders",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Subscription and feature reminders"
                    enableLights(true)
                    lightColor = android.graphics.Color.CYAN
                    enableVibration(true)
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("route", "kids_mode")
            }
            val pendingIntent = PendingIntent.getActivity(
                this,
                notificationId,
                launchIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )

            val notification = NotificationCompat.Builder(this, channelId)
                .setSmallIcon(R.drawable.ic_notification_unlocked)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()

            notificationManager.notify(notificationId, notification)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error showing local reminder notification: ${e.message}")
        }
    }
}