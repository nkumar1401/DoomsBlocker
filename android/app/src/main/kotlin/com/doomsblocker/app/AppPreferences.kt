package com.doomsblocker.app

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AppPreferences(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("dooms_blocker_prefs", Context.MODE_PRIVATE)

    companion object {
        private const val KEY_SHORTS_LIMIT_MINS = "shorts_limit_mins"
        private const val KEY_SHORTS_LOCK_MINS = "shorts_lock_mins"
        private const val KEY_YT_LOCK_UNTIL = "yt_lock_until"
        private const val KEY_SHORTS_USED_SECONDS = "shorts_used_seconds"
        private const val KEY_LAST_RESET_DATE = "last_reset_date"
        private const val KEY_NEPHEW_MODE = "nephew_mode"
        private const val KEY_PARENT_PIN = "parent_pin"
        private const val KEY_GAME_LIMIT_MINS = "game_limit_mins"
        private const val KEY_RESTRICTED_APPS = "restricted_apps"
        private const val KEY_APP_USAGE_SECONDS = "app_usage_seconds"
        private const val KEY_BLOCKED_CHANNELS = "blocked_channels"
    }

    init {
        checkDailyReset()
    }

    private fun checkDailyReset() {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val lastDate = prefs.getString(KEY_LAST_RESET_DATE, "")
        if (today != lastDate) {
            prefs.edit()
                .putString(KEY_LAST_RESET_DATE, today)
                .putInt(KEY_SHORTS_USED_SECONDS, 0)
                .putString(KEY_APP_USAGE_SECONDS, "{}")
                .apply()
        }
    }

    var shortsLimitMinutes: Int
        get() = prefs.getInt(KEY_SHORTS_LIMIT_MINS, 2) // Default: 2 min Shorts limit
        set(value) = prefs.edit().putInt(KEY_SHORTS_LIMIT_MINS, value).apply()

    var shortsLockDurationMinutes: Int
        get() = prefs.getInt(KEY_SHORTS_LOCK_MINS, 30) // Default: 30 min lockout
        set(value) = prefs.edit().putInt(KEY_SHORTS_LOCK_MINS, value).apply()

    var youtubeLockUntilTimestamp: Long
        get() = prefs.getLong(KEY_YT_LOCK_UNTIL, 0L)
        set(value) = prefs.edit().putLong(KEY_YT_LOCK_UNTIL, value).apply()

    val isYouTubeLocked: Boolean
        get() = System.currentTimeMillis() < youtubeLockUntilTimestamp

    var shortsUsedSecondsToday: Int
        get() {
            checkDailyReset()
            return prefs.getInt(KEY_SHORTS_USED_SECONDS, 0)
        }
        set(value) = prefs.edit().putInt(KEY_SHORTS_USED_SECONDS, value).apply()

    fun addShortsUsedSeconds(seconds: Int) {
        val current = shortsUsedSecondsToday
        shortsUsedSecondsToday = current + seconds
    }

    var isNephewModeEnabled: Boolean
        get() = prefs.getBoolean(KEY_NEPHEW_MODE, false)
        set(value) = prefs.edit().putBoolean(KEY_NEPHEW_MODE, value).apply()

    var parentPin: String
        get() = prefs.getString(KEY_PARENT_PIN, "1234") ?: "1234"
        set(value) = prefs.edit().putString(KEY_PARENT_PIN, value).apply()

    var gameLimitMinutes: Int
        get() = prefs.getInt(KEY_GAME_LIMIT_MINS, 20) // Default: 20 min game limit
        set(value) = prefs.edit().putInt(KEY_GAME_LIMIT_MINS, value).apply()

    var restrictedApps: Set<String>
        get() = prefs.getStringSet(KEY_RESTRICTED_APPS, emptySet()) ?: emptySet()
        set(value) = prefs.edit().putStringSet(KEY_RESTRICTED_APPS, value).apply()

    fun getAppUsageSeconds(packageName: String): Int {
        checkDailyReset()
        val jsonStr = prefs.getString(KEY_APP_USAGE_SECONDS, "{}") ?: "{}"
        val json = JSONObject(jsonStr)
        return json.optInt(packageName, 0)
    }

    fun addAppUsageSeconds(packageName: String, seconds: Int) {
        checkDailyReset()
        val jsonStr = prefs.getString(KEY_APP_USAGE_SECONDS, "{}") ?: "{}"
        val json = JSONObject(jsonStr)
        val current = json.optInt(packageName, 0)
        json.put(packageName, current + seconds)
        prefs.edit().putString(KEY_APP_USAGE_SECONDS, json.toString()).apply()
    }

    var blockedChannels: List<String>
        get() {
            val jsonStr = prefs.getString(KEY_BLOCKED_CHANNELS, "[]") ?: "[]"
            val array = JSONArray(jsonStr)
            val list = mutableListOf<String>()
            for (i in 0 until array.length()) {
                list.add(array.getString(i))
            }
            return list
        }
        set(value) {
            val array = JSONArray(value)
            prefs.edit().putString(KEY_BLOCKED_CHANNELS, array.toString()).apply()
        }

    fun getTotalRestrictedAppsUsageSeconds(): Int {
        checkDailyReset()
        val jsonStr = prefs.getString(KEY_APP_USAGE_SECONDS, "{}") ?: "{}"
        val json = JSONObject(jsonStr)
        var total = 0
        for (pkg in restrictedApps) {
            total += json.optInt(pkg, 0)
        }
        return total
    }

    fun unlockYouTubeEmergency() {
        youtubeLockUntilTimestamp = 0L
        shortsUsedSecondsToday = 0
    }

    fun resetGamesUsageEmergency() {
        prefs.edit().putString(KEY_APP_USAGE_SECONDS, "{}").apply()
    }
}
