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

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.doomsblocker.app/control"
    private lateinit var prefs: AppPreferences

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        prefs = AppPreferences(applicationContext)

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
                        "gameLimitMinutes" to prefs.gameLimitMinutes,
                        "restrictedAppsCount" to prefs.restrictedApps.size,
                        "blockedChannelsCount" to prefs.blockedChannels.size
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

                "verifyPin" -> {
                    val pin = call.argument<String>("pin") ?: ""
                    result.success(pin == prefs.parentPin)
                }

                "emergencyUnlockYouTube" -> {
                    val pin = call.argument<String>("pin") ?: ""
                    if (pin == prefs.parentPin) {
                        prefs.unlockYouTubeEmergency()
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

                "checkPermissions" -> {
                    val permissions = mapOf(
                        "accessibility" to isAccessibilityServiceEnabled(),
                        "overlay" to isOverlayPermissionGranted(),
                        "usageStats" to isUsageStatsPermissionGranted()
                    )
                    result.success(permissions)
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

        val list = mutableListOf<Map<String, Any>>()
        for (info in resolveInfos) {
            val pkg = info.activityInfo.packageName
            // Skip self and basic system framework
            if (pkg == packageName) continue

            val label = info.loadLabel(pm).toString()
            val usedSec = prefs.getAppUsageSeconds(pkg)
            val isRestricted = restricted.contains(pkg)

            list.add(
                mapOf(
                    "name" to label,
                    "packageName" to pkg,
                    "isRestricted" to isRestricted,
                    "usedMinutes" to (usedSec / 60)
                )
            )
        }
        return list.sortedByDescending { it["isRestricted"] as Boolean }
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
}
