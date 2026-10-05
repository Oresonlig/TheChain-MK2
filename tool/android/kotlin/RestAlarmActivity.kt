// Larmvyn över låsskärmen: REST OVER + DISMISS / +30 S, i temats färger och
// typsnitt men utan hex-väv (Niklas 2026-10-05). Ingen åtkomst till appen —
// telefonen förblir låst (bara DENNA vy har showWhenLocked, aldrig MainActivity).
package com.oresonlig.the_chain

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

class RestAlarmActivity : Activity() {
    companion object {
        @Volatile var current: RestAlarmActivity? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!RestAlarmService.ringing) {
            finish() // redan avfärdat (t.ex. från notisen)
            return
        }
        current = this
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(buildView())
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
    }

    private fun dp(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics)

    private fun c(key: String, fallback: String) = RestAlarm.color(this, key, Color.parseColor(fallback))

    private fun buildView(): View {
        val bg = c("background", "#05080C")
        val accent = c("accent", "#00D4FF")
        val text = c("textStrong", "#E8F6FF")
        val muted = c("textMuted", "#7F97A8")
        val border = c("borderStrong", "#28485A")
        val font = try {
            Typeface.createFromAsset(assets, "flutter_assets/assets/fonts/Saira-Variable.ttf")
        } catch (_: Exception) {
            Typeface.DEFAULT_BOLD
        }
        window.statusBarColor = bg
        window.navigationBarColor = bg

        fun label(s: String, size: Float, color: Int, spacing: Float) = TextView(this).apply {
            this.text = s
            textSize = size
            setTextColor(color)
            typeface = Typeface.create(font, Typeface.BOLD)
            letterSpacing = spacing
            gravity = Gravity.CENTER
        }

        fun button(s: String, filled: Boolean, onTap: () -> Unit) = label(s, 18f, if (filled) bg else text, 0.15f).apply {
            background = GradientDrawable().apply {
                setColor(if (filled) accent else Color.TRANSPARENT)
                setStroke(dp(1.5f).toInt(), if (filled) accent else border)
            }
            setOnClickListener { onTap() }
            minHeight = dp(64f).toInt()
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(bg)
            val pad = dp(24f).toInt()
            setPadding(pad, pad, pad, pad)
        }
        root.addView(label("REST OVER", 44f, accent, 0.12f))
        root.addView(label("Next set!", 18f, muted, 0.05f), LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(8f).toInt() })
        val buttons = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        buttons.addView(
            button("+30 S", false) { RestAlarm.snooze(this); finish() },
            LinearLayout.LayoutParams(0, dp(64f).toInt(), 1f).apply { rightMargin = dp(12f).toInt() },
        )
        buttons.addView(
            button("DISMISS", true) { RestAlarm.dismiss(this); finish() },
            LinearLayout.LayoutParams(0, dp(64f).toInt(), 2f),
        )
        root.addView(buttons, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(48f).toInt() })
        return root
    }
}
