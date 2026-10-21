package com.doomsblocker.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.CountDownTimer
import android.view.View
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
    private lateinit var tvCountdown: TextView
    private lateinit var btnGoHome: Button
    private lateinit var pinSection: LinearLayout
    private lateinit var tvEmergencyPinToggle: TextView
    private lateinit var pinInputContainer: LinearLayout
    private lateinit var etPin: EditText
    private lateinit var btnUnlockPin: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_overlay_lock)

        prefs = AppPreferences(this)

        tvTitle = findViewById(R.id.tvLockTitle)
        tvMessage = findViewById(R.id.tvLockMessage)
        tvCountdown = findViewById(R.id.tvCountdown)
        btnGoHome = findViewById(R.id.btnGoHome)
        pinSection = findViewById(R.id.pinSection)
        tvEmergencyPinToggle = findViewById(R.id.tvEmergencyPinToggle)
        pinInputContainer = findViewById(R.id.pinInputContainer)
        etPin = findViewById(R.id.etPin)
        btnUnlockPin = findViewById(R.id.btnUnlockPin)

        handleIntent(intent)
        setupPinOverride()

        btnGoHome.setOnClickListener {
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(homeIntent)
            finish()
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
                tvTitle.text = "YouTube Shorts Limit Reached"
                tvMessage.text = "You scrolled Shorts for ${prefs.shortsLimitMinutes} minutes.\nYouTube is now locked for ${prefs.shortsLockDurationMinutes} minutes to avoid doomscrolling."
                startLockdownTimer()
            }
            REASON_YOUTUBE_LOCKED -> {
                tvTitle.text = "YouTube is Locked"
                tvMessage.text = "YouTube remains locked until the lock timer expires. Take a break!"
                startLockdownTimer()
            }
            REASON_GAME_LIMIT -> {
                tvTitle.text = "Game Time Limit Reached"
                val appLabel = if (blockedItem.isNotEmpty()) blockedItem else "Games"
                tvMessage.text = "$appLabel reached the ${prefs.gameLimitMinutes}-minute daily combined limit under Nephew Mode."
                tvCountdown.text = "LIMIT OVER"
            }
            REASON_CHANNEL_BLOCKED -> {
                tvTitle.text = "Restricted YouTube Channel"
                tvMessage.text = "The channel \"$blockedItem\" is blocked by your parental restriction rules."
                tvCountdown.text = "BLOCKED"
            }
        }
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
            pinInputContainer.visibility =
                if (pinInputContainer.visibility == View.VISIBLE) View.GONE else View.VISIBLE
        }

        btnUnlockPin.setOnClickListener {
            val entered = etPin.text.toString().trim()
            if (entered == prefs.parentPin) {
                prefs.unlockYouTubeEmergency()
                prefs.resetGamesUsageEmergency()
                countDownTimer?.cancel()
                Toast.makeText(this, "Parent PIN accepted! Lock released.", Toast.LENGTH_SHORT).show()
                finish()
            } else {
                Toast.makeText(this, "Incorrect PIN. Try again.", Toast.LENGTH_SHORT).show()
            }
        }
    }

    override fun onBackPressed() {
        // Prevent bypassing the lock screen by pressing back. Redirect home instead.
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        countDownTimer?.cancel()
    }
}
