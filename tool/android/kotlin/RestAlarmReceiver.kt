// Exakta larmet vid noll + notisens knappar (DISMISS / +30 S). Se RestAlarm.kt.
package com.oresonlig.the_chain

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class RestAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        when (intent.action) {
            RestAlarm.ACTION_FIRE -> {
                if (RestAlarm.endMs(ctx) == 0L) return // avbrutet under tiden
                val svc = Intent(ctx, RestAlarmService::class.java)
                // Ett exakt larm får starta en förgrundstjänst från bakgrunden.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ctx.startForegroundService(svc) else ctx.startService(svc)
            }
            RestAlarm.ACTION_DISMISS -> RestAlarm.dismiss(ctx)
            RestAlarm.ACTION_SNOOZE -> RestAlarm.snooze(ctx)
        }
    }
}
