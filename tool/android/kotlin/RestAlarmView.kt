// Larmvyns utseende — EN källa för både låsskärmen (RestAlarmActivity) och
// lagret ovanpå andra appar (RestAlarmService). REST OVER + +30 S / DISMISS, i
// temats färger och typsnitt men utan hex-väv (Niklas 2026-10-05).
// Tryck på rutan utanför knapparna = larmet av + appen öppnas (Niklas 2026-10-09);
// knappraden sväljer sina egna missar så att ett slarvtryck där inte öppnar appen.
package com.oresonlig.the_chain

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView

object RestAlarmView {
    fun background(ctx: Context) = RestAlarm.color(ctx, "background", Color.parseColor("#05080C"))

    fun build(ctx: Context, onSnooze: () -> Unit, onDismiss: () -> Unit, onOpen: () -> Unit): View {
        fun dp(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, ctx.resources.displayMetrics)
        fun c(key: String, fallback: String) = RestAlarm.color(ctx, key, Color.parseColor(fallback))
        val bg = background(ctx)
        val accent = c("accent", "#00D4FF")
        val text = c("textStrong", "#E8F6FF")
        val muted = c("textMuted", "#7F97A8")
        val border = c("borderStrong", "#28485A")
        val font = try {
            Typeface.createFromAsset(ctx.assets, "flutter_assets/assets/fonts/Saira-Variable.ttf")
        } catch (_: Exception) {
            Typeface.DEFAULT_BOLD
        }

        fun label(s: String, size: Float, color: Int, spacing: Float) = TextView(ctx).apply {
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

        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(bg)
            val pad = dp(24f).toInt()
            setPadding(pad, pad, pad, pad)
            setOnClickListener { onOpen() }
        }
        root.addView(label("REST OVER", 44f, accent, 0.12f))
        root.addView(label("Next set!", 18f, muted, 0.05f), LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(8f).toInt() })
        root.addView(label("Tap to open The Chain", 13f, muted, 0.05f), LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(4f).toInt() })
        val buttons = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            isClickable = true
        }
        buttons.addView(
            button("+30 S", false, onSnooze),
            LinearLayout.LayoutParams(0, dp(64f).toInt(), 1f).apply { rightMargin = dp(12f).toInt() },
        )
        buttons.addView(button("DISMISS", true, onDismiss), LinearLayout.LayoutParams(0, dp(64f).toInt(), 2f))
        root.addView(buttons, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(48f).toInt() })
        return root
    }
}
