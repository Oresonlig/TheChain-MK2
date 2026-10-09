// Vilotimerns larmmotor (Niklas 2026-10-05: "som klockans larm"). Kopieras in
// av tool/configure_android.mjs — android/ genereras i CI och spåras inte.
//
// Flöde: Flutter schemalägger sluttiden → exakt larm (AlarmManager) →
// RestAlarmReceiver → RestAlarmService (förgrundstjänst: pip i loop, vibration,
// musiken pausas via tillfällig ljudfokus) + helskärmsnotis → RestAlarmActivity
// över låsskärmen (REST OVER, DISMISS, +30 S; tryck på rutan = appen, men först
// efter Androids egen upplåsning — telefonen förblir låst).
// DISMISS/+30/60 s → fokus lämnas tillbaka → musiken fortsätter.
package com.oresonlig.the_chain

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

object RestAlarm {
    const val CH_COUNTDOWN = "rest_countdown_v3"
    const val CH_ALARM = "rest_alarm_v3"
    const val ID_COUNTDOWN = 7101
    const val ID_ALARM = 7102
    const val ACTION_FIRE = "com.oresonlig.the_chain.REST_FIRE"
    const val ACTION_DISMISS = "com.oresonlig.the_chain.REST_DISMISS"
    const val ACTION_SNOOZE = "com.oresonlig.the_chain.REST_SNOOZE"
    const val SNOOZE_SECS = 30
    const val RING_MAX_MS = 60_000L

    /** Kanaler från bygge 58–62 (flutter_local_notifications). */
    private val OLD_CHANNELS = listOf("rest_done", "rest_alert", "rest_countdown", "rest_alert_v2", "rest_countdown_v2")

    /** Satt av MainActivity medan Flutter lever: native → Flutter (stoppad / +30). */
    @Volatile var channel: MethodChannel? = null

    private fun prefs(ctx: Context) = ctx.getSharedPreferences("rest_alarm", Context.MODE_PRIVATE)

    fun endMs(ctx: Context): Long = prefs(ctx).getLong("end", 0L)
    fun wakeScreen(ctx: Context): Boolean = prefs(ctx).getBoolean("wake", true)
    fun color(ctx: Context, key: String, fallback: Int): Int = prefs(ctx).getInt("c_$key", fallback)

    fun schedule(ctx: Context, endMs: Long, wake: Boolean, look: Map<String, Int>?) {
        stopRinging(ctx)
        val e = prefs(ctx).edit().putLong("end", endMs).putBoolean("wake", wake)
        look?.forEach { (k, v) -> e.putInt("c_$k", v) }
        e.apply()
        ensureChannels(ctx)
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = firePending(ctx)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endMs, pi)
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endMs, pi)
        }
        postCountdown(ctx, endMs)
    }

    fun cancel(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(firePending(ctx))
        nm(ctx).cancel(ID_COUNTDOWN)
        stopRinging(ctx)
        prefs(ctx).edit().putLong("end", 0L).apply()
    }

    /** DISMISS (larmvyn, notisknappen, Flutter) eller 60 s utan svar. */
    fun dismiss(ctx: Context) {
        cancel(ctx)
        tellFlutter("stopped", null)
    }

    /** +30 S: tyst nu, ny vila på 30 s. */
    fun snooze(ctx: Context) {
        val end = System.currentTimeMillis() + SNOOZE_SECS * 1000L
        schedule(ctx, end, wakeScreen(ctx), null)
        tellFlutter("snoozed", end)
    }

    fun state(ctx: Context): Map<String, Any> =
        mapOf("ringing" to RestAlarmService.ringing, "end" to endMs(ctx))

    fun stopRinging(ctx: Context) {
        RestAlarmActivity.current?.finish()
        if (RestAlarmService.ringing) ctx.stopService(Intent(ctx, RestAlarmService::class.java))
        nm(ctx).cancel(ID_ALARM)
    }

    private fun tellFlutter(method: String, arg: Any?) {
        Handler(Looper.getMainLooper()).post { channel?.invokeMethod(method, arg) }
    }

    fun nm(ctx: Context) = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private const val FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    private fun firePending(ctx: Context): PendingIntent =
        PendingIntent.getBroadcast(ctx, 1, Intent(ctx, RestAlarmReceiver::class.java).setAction(ACTION_FIRE), FLAGS)

    fun actionPending(ctx: Context, action: String, code: Int): PendingIntent =
        PendingIntent.getBroadcast(ctx, code, Intent(ctx, RestAlarmReceiver::class.java).setAction(action), FLAGS)

    fun alarmViewPending(ctx: Context): PendingIntent =
        PendingIntent.getActivity(
            ctx, 4,
            Intent(ctx, RestAlarmActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION),
            FLAGS,
        )

    /** Appens startskärm (MainActivity, singleTask → befintlig instans tas fram). */
    fun launchIntent(ctx: Context): Intent? =
        ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    private fun openAppPending(ctx: Context): PendingIntent? {
        val i = launchIntent(ctx) ?: return null
        return PendingIntent.getActivity(ctx, 5, i, FLAGS)
    }

    fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = nm(ctx)
        OLD_CHANNELS.forEach { nm.deleteNotificationChannel(it) }
        nm.createNotificationChannel(
            NotificationChannel(CH_COUNTDOWN, "Rest timer countdown", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Silent countdown while you rest"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            },
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_ALARM, "Rest timer alarm", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Rest over: beeps, vibrates, pauses your music and wakes the screen"
                setShowBadge(false)
                // Ljud och vibration spelar tjänsten själv (ljudfokus = musiken pausas).
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
        )
    }

    private fun postCountdown(ctx: Context, endMs: Long) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val left = endMs - System.currentTimeMillis()
        if (left <= 0) return
        val n = Notification.Builder(ctx, CH_COUNTDOWN)
            .setSmallIcon(ctx.applicationInfo.icon)
            .setContentTitle("Resting")
            .setContentText("Next set when the timer hits zero")
            .setShowWhen(true)
            .setWhen(endMs)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setTimeoutAfter(left)
            .setCategory(Notification.CATEGORY_STOPWATCH)
            .setContentIntent(openAppPending(ctx))
            .build()
        nm(ctx).notify(ID_COUNTDOWN, n)
    }
}
