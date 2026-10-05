// Larmet när vilan är slut: pip i loop (ljud på) / bara vibration (ljudlöst
// eller vibrationsläge, som klockans larm), musiken pausas via TILLFÄLLIG
// ljudfokus och fortsätter när fokus lämnas tillbaka. Tystnar efter 60 s.
package com.oresonlig.the_chain

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

class RestAlarmService : Service() {
    companion object {
        @Volatile var ringing = false
    }

    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    /// Håller processorn vaken medan larmet går: på ljudlöst (bara vibration)
    /// kunde den annars somna och 60-sekunderstimeouten kom aldrig (Niklas b63).
    private var wakeLock: PowerManager.WakeLock? = null
    private var focus: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { RestAlarm.dismiss(this) }

    private val alarmAttrs: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (ringing) return START_NOT_STICKY
        ringing = true
        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "thechain:restalarm")
            .apply { acquire(RestAlarm.RING_MAX_MS + 5_000L) }
        RestAlarm.ensureChannels(this)
        RestAlarm.nm(this).cancel(RestAlarm.ID_COUNTDOWN)
        val n = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(RestAlarm.ID_ALARM, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(RestAlarm.ID_ALARM, n)
        }
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // Musiken pausas även i ljudlöst — som klockans larm (Niklas testade).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(alarmAttrs)
                .setOnAudioFocusChangeListener { }
                .build()
            am.requestAudioFocus(focus!!)
        }
        if (am.ringerMode == AudioManager.RINGER_MODE_NORMAL) startBeep()
        startVibration()
        handler.postDelayed(timeout, RestAlarm.RING_MAX_MS)
        return START_NOT_STICKY
    }

    private fun startBeep() {
        try {
            player = MediaPlayer().apply {
                setAudioAttributes(alarmAttrs)
                setDataSource(this@RestAlarmService, Uri.parse("android.resource://$packageName/${R.raw.rest_beep}"))
                isLooping = true
                prepare()
                start()
            }
        } catch (_: Exception) {
            player = null // vibrationen bär signalen ändå
        }
    }

    private fun startVibration() {
        val v = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION") getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        vibrator = v
        val pattern = longArrayOf(0, 500, 200, 500, 200, 500, 1200)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Larm-attribut: vibrerar även i ljudlöst läge.
            @Suppress("DEPRECATION") v.vibrate(VibrationEffect.createWaveform(pattern, 0), alarmAttrs)
        } else {
            @Suppress("DEPRECATION") v.vibrate(pattern, 0)
        }
    }

    private fun buildNotification(): Notification {
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, RestAlarm.CH_ALARM)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        b.setSmallIcon(applicationInfo.icon)
            .setContentTitle("Rest over")
            .setContentText("Next set!")
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setContentIntent(RestAlarm.alarmViewPending(this))
            .addAction(Notification.Action.Builder(null as Icon?, "+30 S", RestAlarm.actionPending(this, RestAlarm.ACTION_SNOOZE, 2)).build())
            .addAction(Notification.Action.Builder(null as Icon?, "DISMISS", RestAlarm.actionPending(this, RestAlarm.ACTION_DISMISS, 3)).build())
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION") b.setPriority(Notification.PRIORITY_MAX)
        }
        // Skärmen tänds och larmvyn visas över låsskärmen (Settings → SCREEN WAKE-UP).
        // Används man telefonen blir det i stället en notis med knapparna.
        if (RestAlarm.wakeScreen(this)) b.setFullScreenIntent(RestAlarm.alarmViewPending(this), true)
        return b.build()
    }

    override fun onDestroy() {
        handler.removeCallbacks(timeout)
        try {
            player?.stop()
        } catch (_: Exception) {
        }
        player?.release()
        player = null
        vibrator?.cancel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focus?.let { (getSystemService(Context.AUDIO_SERVICE) as AudioManager).abandonAudioFocusRequest(it) }
        }
        ringing = false
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        RestAlarmActivity.current?.finish()
        super.onDestroy()
    }
}
