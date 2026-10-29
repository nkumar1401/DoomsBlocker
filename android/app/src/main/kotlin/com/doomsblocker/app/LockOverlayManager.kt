package com.doomsblocker.app

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

/**
 * Native WindowManager Overlay Manager.
 *
 * Renders the 5-second countdown lock view directly using WindowManager.addView
 * (TYPE_APPLICATION_OVERLAY).
 *
 * Invariant: Completely immune to OEM Background Activity Launch (BAL) blocks
 * (Xiaomi/MIUI/HyperOS, Samsung, Vivo, Oppo) because it does not rely on startActivity().
 */
object LockOverlayManager {
    private const val TAG = "LockOverlayManager"
    private var overlayView: View? = null
    private var countDownTimer: CountDownTimer? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun show(
        context: Context,
        reason: String,
        blockedItem: String? = null,
        targetPackage: String? = null
    ) {
        mainHandler.post {
            try {
                if (!Settings.canDrawOverlays(context)) {
                    Log.w(TAG, "Cannot draw overlay: SYSTEM_ALERT_WINDOW not granted")
                    return@post
                }

                if (overlayView != null) {
                    // Overlay is already visible
                    return@post
                }

                val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                    ?: return@post

                val inflater = LayoutInflater.from(context)
                val view = inflater.inflate(R.layout.activity_overlay_lock, null)

                val tvTitle = view.findViewById<TextView>(R.id.tvLockTitle)
                val tvMessage = view.findViewById<TextView>(R.id.tvLockMessage)
                val tvCountdown = view.findViewById<TextView>(R.id.tvCountdown)
                val btnGoHome = view.findViewById<Button>(R.id.btnGoHome)
                val btnClose = view.findViewById<TextView>(R.id.btnCloseOverlay)
                val pinSection = view.findViewById<View>(R.id.pinSection)

                // Hide PIN section in WindowManager overlay to keep it a clean, unblockable 5s countdown
                pinSection?.visibility = View.GONE

                val prefs = AppPreferences(context)
                when (reason) {
                    OverlayLockActivity.REASON_SHORTS_LIMIT -> {
                        tvTitle?.text = context.getString(R.string.lock_title_shorts)
                        tvMessage?.text = context.getString(
                            R.string.lock_message_shorts,
                            prefs.shortsLimitMinutes,
                            prefs.shortsLockDurationMinutes
                        )
                    }
                    OverlayLockActivity.REASON_YOUTUBE_LOCKED -> {
                        tvTitle?.text = context.getString(R.string.lock_title_youtube_nephew)
                        tvMessage?.text = context.getString(R.string.lock_message_youtube_nephew)
                    }
                    OverlayLockActivity.REASON_GAME_LIMIT -> {
                        val appName = blockedItem ?: "Game"
                        tvTitle?.text = context.getString(R.string.lock_title_game, appName)
                        tvMessage?.text = context.getString(R.string.lock_message_game, appName, prefs.gameLimitMinutes)
                    }
                    OverlayLockActivity.REASON_CHANNEL_BLOCKED -> {
                        val channel = blockedItem ?: "Channel"
                        tvTitle?.text = "Channel Blocked"
                        tvMessage?.text = "Videos from \"$channel\" are restricted."
                    }
                    OverlayLockActivity.REASON_STUDY_ZONE -> {
                        val library = blockedItem ?: "Study Zone"
                        tvTitle?.text = "Library Study Zone Active"
                        tvMessage?.text = "Focus mode is locked for $library. Distraction apps are disabled."
                    }
                }

                val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    layoutType,
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_FULLSCREEN,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.CENTER
                }

                val onGoHome = View.OnClickListener {
                    dismiss(context)
                    val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(homeIntent)
                }

                btnGoHome?.setOnClickListener(onGoHome)
                btnClose?.setOnClickListener(onGoHome)

                // 5-second smooth countdown
                countDownTimer = object : CountDownTimer(5000, 1000) {
                    override fun onTick(millisUntilFinished: Long) {
                        val seconds = (millisUntilFinished / 1000).toInt() + 1
                        tvCountdown?.text = "${seconds}s"
                    }

                    override fun onFinish() {
                        tvCountdown?.text = "0s"
                        dismiss(context)
                        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context.startActivity(homeIntent)
                    }
                }.start()

                windowManager.addView(view, params)
                overlayView = view
                Log.d(TAG, "Multi-Brand WindowManager overlay displayed successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Error displaying WindowManager overlay: ${e.message}")
            }
        }
    }

    fun dismiss(context: Context) {
        mainHandler.post {
            try {
                countDownTimer?.cancel()
                countDownTimer = null
                if (overlayView != null) {
                    val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                    windowManager?.removeView(overlayView)
                    overlayView = null
                    Log.d(TAG, "WindowManager overlay dismissed")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error dismissing WindowManager overlay: ${e.message}")
            }
        }
    }
}
