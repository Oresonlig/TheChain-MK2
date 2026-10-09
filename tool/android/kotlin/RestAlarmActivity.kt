// Larmvyn över LÅSSKÄRMEN (öppnas av helskärmsnotisen). Telefonen förblir
// låst (bara DENNA vy har showWhenLocked, aldrig MainActivity). Tryck på rutan
// = larmet av + Androids egen upplåsning; appen öppnas BARA om den lyckas,
// avbruten upplåsning = kvar på låsskärmen (Niklas 2026-10-09). Utseendet:
// RestAlarmView. När telefonen används ritar RestAlarmService samma vy som ett
// lager ovanpå andra appar i stället.
package com.oresonlig.the_chain

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.WindowManager

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
        val bg = RestAlarmView.background(this)
        window.statusBarColor = bg
        window.navigationBarColor = bg
        setContentView(
            RestAlarmView.build(
                this,
                onSnooze = { RestAlarm.snooze(this); finish() },
                onDismiss = { RestAlarm.dismiss(this); finish() },
                onOpen = { openApp() },
            ),
        )
    }

    private fun openApp() {
        // Larmet av direkt, men vyn måste leva tills upplåsningen svarat —
        // därför släpps `current` först (dismiss stänger annars vyn).
        current = null
        RestAlarm.dismiss(this)
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (!km.isKeyguardLocked) {
            startApp()
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            finish()
            return
        }
        km.requestDismissKeyguard(
            this,
            object : KeyguardManager.KeyguardDismissCallback() {
                override fun onDismissSucceeded() = startApp()
                override fun onDismissCancelled() = finish()
                override fun onDismissError() = finish()
            },
        )
    }

    private fun startApp() {
        try {
            RestAlarm.launchIntent(this)?.let { startActivity(it) }
        } catch (_: Exception) {
        }
        finish()
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
    }
}
