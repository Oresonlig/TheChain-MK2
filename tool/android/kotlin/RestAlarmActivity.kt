// Larmvyn över LÅSSKÄRMEN (öppnas av helskärmsnotisen). Ingen åtkomst till
// appen — telefonen förblir låst (bara DENNA vy har showWhenLocked, aldrig
// MainActivity). Utseendet: RestAlarmView. När telefonen används ritar
// RestAlarmService samma vy som ett lager ovanpå andra appar i stället.
package com.oresonlig.the_chain

import android.app.Activity
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
            ),
        )
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
    }
}
