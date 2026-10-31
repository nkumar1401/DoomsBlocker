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
                val tvEmergencyPinToggle = view.findViewById<TextView>(R.id.tvEmergencyPinToggle)
                val pinInputContainer = view.findViewById<View>(R.id.pinInputContainer)
                val etPin = view.findViewById<android.widget.EditText>(R.id.etPin)
                val btnUnlockPin = view.findViewById<Button>(R.id.btnUnlockPin)

                if (reason == OverlayLockActivity.REASON_STUDY_ZONE) {
                    pinSection?.visibility = View.GONE
                } else {
                    pinSection?.visibility = View.VISIBLE
                }

                val prefs = AppPreferences(context)
                when (reason) {
                    OverlayLockActivity.REASON_SHORTS_LIMIT -> {
                        val limitMins = prefs.shortsLimitMinutes
                        val lockMins = prefs.shortsLockDurationMinutes
                        when (targetPackage) {
                            AppPreferences.PKG_INSTAGRAM -> {
                                tvTitle?.text = "Instagram Locked"
                                tvMessage?.text = "Short-form limit reached ($limitMins min).\nInstagram is locked for $lockMins min to prevent doomscrolling."
                            }
                            AppPreferences.PKG_SNAPCHAT -> {
                                tvTitle?.text = "Snapchat Spotlight Blocked"
                                tvMessage?.text = "Short-form limit reached ($limitMins min).\nSpotlight is locked for $lockMins min.\n(Snapchat chat, camera & stories remain accessible)."
                            }
                            AppPreferences.PKG_SHARECHAT -> {
                                tvTitle?.text = "ShareChat Locked"
                                tvMessage?.text = "Short-form limit reached ($limitMins min).\nShareChat is locked for $lockMins min to prevent doomscrolling."
                            }
                            AppPreferences.PKG_MOJ -> {
                                tvTitle?.text = "Moj Locked"
                                tvMessage?.text = "Short-form limit reached ($limitMins min).\nMoj is locked for $lockMins min to prevent doomscrolling."
                            }
                            AppPreferences.PKG_JOSH -> {
                                tvTitle?.text = "Josh Locked"
                                tvMessage?.text = "Short-form limit reached ($limitMins min).\nJosh is locked for $lockMins min to prevent doomscrolling."
                            }
                            else -> {
                                tvTitle?.text = "YouTube Shorts Blocked"
                                tvMessage?.text = "Shorts limit reached ($limitMins min).\nShorts is locked for $lockMins min.\n(Long-form YouTube videos remain accessible)."
                            }
                        }
                    }
                    OverlayLockActivity.REASON_YOUTUBE_LOCKED -> {
                        tvTitle?.text = "YouTube Limit Reached"
                        tvMessage?.text = if (prefs.isKidsModeEnabled) {
                            "Kids Mode: Daily YouTube viewing limit reached (${prefs.shortsLimitMinutes} min).\nLocked for a 30-minute cooldown break."
                        } else {
                            "YouTube access remains locked until timer expires. Take a break!"
                        }
                    }
                    OverlayLockActivity.REASON_KIDS_SHORTS_BLOCKED -> {
                        tvTitle?.text = "Shorts & Reels Blocked"
                        tvMessage?.text = "Shorts & Reels are completely blocked in Kids Mode.\nLong-form videos and tutorials are allowed!"
                    }
                    OverlayLockActivity.REASON_KIDS_SOCIAL_BLOCKED -> {
                        val appLabel = if (!blockedItem.isNullOrEmpty()) blockedItem else "Social Media"
                        tvTitle?.text = "$appLabel Blocked"
                        tvMessage?.text = "Social media applications are completely locked in Kids Mode to protect children."
                    }
                    OverlayLockActivity.REASON_GAME_LIMIT -> {
                        val appLabel = if (!blockedItem.isNullOrEmpty()) blockedItem else "Games"
                        tvTitle?.text = "Game Time Limit Reached"
                        tvMessage?.text = "$appLabel reached the ${prefs.gameLimitMinutes}-minute daily limit under Kids Mode."
                    }
                    OverlayLockActivity.REASON_CHANNEL_BLOCKED -> {
                        val channel = blockedItem ?: "Channel"
                        tvTitle?.text = "Restricted YouTube Channel"
                        tvMessage?.text = "The channel \"$channel\" is blocked by your parental restriction rules."
                    }
                    OverlayLockActivity.REASON_STUDY_ZONE -> {
                        val library = if (!blockedItem.isNullOrEmpty()) blockedItem else prefs.studyZoneName
                        tvTitle?.text = "📚 Study Zone Active"
                        tvMessage?.text = "You are currently in a focused study session at $library.\nDistractions (Instagram, Games & Shorts) are locked."
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

                tvEmergencyPinToggle?.setOnClickListener {
                    // Tapping PIN toggle pauses 5-second countdown so user can type!
                    countDownTimer?.cancel()
                    tvCountdown?.text = "PAUSED"
                    pinInputContainer?.visibility = View.VISIBLE
                    etPin?.requestFocus()
                }

                btnUnlockPin?.setOnClickListener {
                    val entered = etPin?.text?.toString()?.trim() ?: ""
                    if (prefs.isPinSet && entered == prefs.parentPin) {
                        prefs.unlockYouTubeEmergency()
                        prefs.resetGamesUsageEmergency()
                        dismiss(context)
                        val pkgToLaunch = targetPackage
                        if (!pkgToLaunch.isNullOrEmpty()) {
                            val resumeIntent = context.packageManager.getLaunchIntentForPackage(pkgToLaunch)?.apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            }
                            if (resumeIntent != null) {
                                context.startActivity(resumeIntent)
                            }
                        }
                    } else {
                        android.widget.Toast.makeText(context, "Incorrect PIN", android.widget.Toast.LENGTH_SHORT).show()
                    }
                }

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
