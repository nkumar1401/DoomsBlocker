package com.doomsblocker.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            try {
                AppMonitorForegroundService.start(context)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
