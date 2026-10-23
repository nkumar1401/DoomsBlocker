package com.doomsblocker.app

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.CountDownTimer
import android.util.Log
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import java.util.Locale

class OverlayLockActivity : Activity() {

    companion object {
        const val EXTRA_REASON = "extra_lock_reason"
        const val EXTRA_BLOCKED_ITEM = "extra_blocked_item"
        const val REASON_SHORTS_LIMIT = "reason_shorts_limit"
        const val REASON_YOUTUBE_LOCKED = "reason_youtube_locked"
        const val REASON_GAME_LIMIT = "reason_game_limit"
        const val REASON_CHANNEL_BLOCKED = "reason_channel_blocked"

        fun start(context: Context, reason: String, blockedItem: String? = null) {
            val intent = Intent(context, OverlayLockActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(EXTRA_REASON, reason)
                putExtra(EXTRA_BLOCKED_ITEM, blockedItem)
            }
            context.startActivity(intent)
        }
    }

    private lateinit var prefs: AppPreferences
    private var countDownTimer: CountDownTimer? = null

    private lateinit var tvTitle: TextView
    private lateinit var tvMessage: TextView
    private lateinit var tvCountdownLabel: TextView
    private lateinit var tvCountdown: TextView
    private lateinit var btnGoHome: Button
    private lateinit var pinSection: LinearLayout
    private lateinit var tvEmergencyPinToggle: TextView
    private lateinit var pinInputContainer: LinearLayout
    private lateinit var etPin: EditText
    private lateinit var btnUnlockPin: Button
    private lateinit var btnCloseOverlay: TextView
    private var failedPinAttempts = 0

    private val dismissReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_overlay_lock)

        prefs = AppPreferences(this)

        val filter = IntentFilter("com.doomsblocker.ACTION_DISMISS_OVERLAY")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(dismissReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(dismissReceiver, filter)
        }

        tvTitle = findViewById(R.id.tvLockTitle)
        tvMessage = findViewById(R.id.tvLockMessage)
        tvCountdownLabel = findViewById(R.id.tvCountdownLabel)
        tvCountdown = findViewById(R.id.tvCountdown)
        btnGoHome = findViewById(R.id.btnGoHome)
        btnCloseOverlay = findViewById(R.id.btnCloseOverlay)
        pinSection = findViewById(R.id.pinSection)
        tvEmergencyPinToggle = findViewById(R.id.tvEmergencyPinToggle)
        pinInputContainer = findViewById(R.id.pinInputContainer)
        etPin = findViewById(R.id.etPin)
        btnUnlockPin = findViewById(R.id.btnUnlockPin)

        handleIntent(intent)
        setupPinOverride()

        btnGoHome.setOnClickListener {
            goToHomeScreen()
        }

        btnCloseOverlay.setOnClickListener {
            goToHomeScreen()
        }
    }

    override fun onResume() {
        super.onResume()
        if (!prefs.isYouTubeLocked) {
            val reason = intent?.getStringExtra(EXTRA_REASON)
            if (reason == REASON_YOUTUBE_LOCKED || reason == REASON_SHORTS_LIMIT) {
                finish()
            }
        }
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        intent?.let { handleIntent(it) }
    }

    private fun handleIntent(intent: Intent) {
        val reason = intent.getStringExtra(EXTRA_REASON) ?: REASON_SHORTS_LIMIT
        val blockedItem = intent.getStringExtra(EXTRA_BLOCKED_ITEM) ?: ""

        when (reason) {
            REASON_SHORTS_LIMIT -> {
                tvTitle.text = "YouTube Shorts Blocked"
                tvMessage.text = "Shorts limit reached (${prefs.shortsLimitMinutes} min).\nShorts is locked for ${prefs.shortsLockDurationMinutes} min.\n(Long-form YouTube videos remain accessible)."
                // Smooth 5-second auto-dismiss to Home Screen
                startAutoDismissTimer(5)
            }
            REASON_YOUTUBE_LOCKED -> {
                tvTitle.text = "YouTube is Locked"
                if (prefs.isNephewModeEnabled) {
                    tvMessage.text = "Nephew Mode Active: Complete YouTube access is locked for ${prefs.shortsLockDurationMinutes} minutes."
                } else {
                    tvMessage.text = "YouTube access remains locked until timer expires. Take a break!"
                }
                tvCountdownLabel.text = "LOCKOUT TIME REMAINING"
                startLockdownTimer()
            }
            REASON_GAME_LIMIT -> {
                tvTitle.text = "Game Time Limit Reached"
                val appLabel = if (blockedItem.isNotEmpty()) blockedItem else "Games"
                tvMessage.text = "$appLabel reached the ${prefs.gameLimitMinutes}-minute daily limit under Nephew Mode."
                startAutoDismissTimer(5)
            }
            REASON_CHANNEL_BLOCKED -> {
                tvTitle.text = "Restricted YouTube Channel"
                tvMessage.text = "The channel \"$blockedItem\" is blocked by your parental restriction rules."
                startAutoDismissTimer(5)
            }
        }
    }

    private fun startAutoDismissTimer(seconds: Int) {
        countDownTimer?.cancel()
        tvCountdownLabel.text = "RETURNING TO HOME IN"
        tvCountdown.text = "${seconds}s"

        countDownTimer = object : CountDownTimer(seconds * 1000L, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val sec = (millisUntilFinished / 1000).toInt() + 1
                tvCountdown.text = "${sec}s"
            }

            override fun onFinish() {
                tvCountdown.text = "0s"
                goToHomeScreen()
            }
        }.start()
    }

    private fun startLockdownTimer() {
        countDownTimer?.cancel()
        val now = System.currentTimeMillis()
        val remainingMillis = prefs.youtubeLockUntilTimestamp - now

        if (remainingMillis <= 0) {
            tvCountdown.text = "00:00"
            finish()
            return
        }

        countDownTimer = object : CountDownTimer(remainingMillis, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val totalSeconds = millisUntilFinished / 1000
                val minutes = totalSeconds / 60
                val seconds = totalSeconds % 60
                tvCountdown.text = String.format(Locale.US, "%02d:%02d", minutes, seconds)
            }

            override fun onFinish() {
                tvCountdown.text = "00:00"
                Toast.makeText(this@OverlayLockActivity, "Lock period expired! YouTube is available.", Toast.LENGTH_LONG).show()
                finish()
            }
        }.start()
    }

    private fun setupPinOverride() {
        tvEmergencyPinToggle.setOnClickListener {
            val isCurrentlyVisible = pinInputContainer.visibility == View.VISIBLE
            if (!isCurrentlyVisible) {
                // Open PIN input: Pause auto-dismiss timer so user has unlimited time to type!
                pinInputContainer.visibility = View.VISIBLE
                countDownTimer?.cancel()
                tvCountdownLabel.text = "PIN UNLOCK ACTIVE"
                tvCountdown.text = "PAUSED"
                etPin.requestFocus()
                val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                imm?.showSoftInput(etPin, InputMethodManager.SHOW_IMPLICIT)
            } else {
                // Close PIN input: restart auto-dismiss countdown
                pinInputContainer.visibility = View.GONE
                val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                imm?.hideSoftInputFromWindow(etPin.windowToken, 0)
                startAutoDismissTimer(5)
            }
        }

        btnUnlockPin.setOnClickListener {
            val entered = etPin.text.toString().trim()
            if (entered == prefs.parentPin) {
                failedPinAttempts = 0
                prefs.unlockYouTubeEmergency()
                prefs.resetGamesUsageEmergency()
                countDownTimer?.cancel()
                Toast.makeText(this, "Parent PIN accepted! Resuming YouTube...", Toast.LENGTH_SHORT).show()

                // Seamlessly reopen YouTube directly
                try {
                    val ytIntent = packageManager.getLaunchIntentForPackage("com.google.android.youtube")?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                    if (ytIntent != null) {
                        startActivity(ytIntent)
                    }
                } catch (e: Exception) {
                    Log.e("OverlayLockActivity", "Error reopening YouTube: ${e.message}")
                }

                finish()
            } else {
                failedPinAttempts++
                val remainingAttempts = 3 - failedPinAttempts
                if (remainingAttempts > 0) {
                    Toast.makeText(this, "Incorrect PIN. $remainingAttempts attempt(s) remaining.", Toast.LENGTH_SHORT).show()
                    etPin.text.clear()
                } else {
                    Toast.makeText(this, "Maximum attempts reached. Returning to Home...", Toast.LENGTH_LONG).show()
                    pinInputContainer.visibility = View.GONE
                    val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                    imm?.hideSoftInputFromWindow(etPin.windowToken, 0)
                    failedPinAttempts = 0
                    startAutoDismissTimer(3)
                }
            }
        }
    }

    private fun goToHomeScreen() {
        countDownTimer?.cancel()
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        startActivity(homeIntent)
        finish()
    }

    override fun onBackPressed() {
        goToHomeScreen()
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(dismissReceiver)
        } catch (e: Exception) {
            // ignore
        }
        countDownTimer?.cancel()
    }
}
