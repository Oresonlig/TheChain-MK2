// Larmet när vilan är slut: pip i loop (ljud på) / bara vibration (ljudlöst
// eller vibrationsläge, som klockans larm), musiken pausas via TILLFÄLLIG
// ljudfokus och fortsätter när fokus lämnas tillbaka. Tystnar efter 60 s.
package com.oresonlig.the_chain

import android.app.KeyguardManager
import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
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
import android.provider.Settings
import android.view.View
import android.view.WindowManager

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

    /// Android spelar ALLTID alarm i högtalaren, även med hörlurar i (LT
    /// 2026-10-08: "Loud af"). Med hörlurar spelas pipet som media i stället —
    /// det följer hörlurarna och mediavolymen.
    private val mediaAttrs: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private fun headphonesOn(am: AudioManager): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val types = mutableSetOf(
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) types.add(AudioDeviceInfo.TYPE_USB_HEADSET)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) types.add(AudioDeviceInfo.TYPE_BLE_HEADSET)
        return am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any { it.type in types }
    }

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
        val soundAttrs = if (headphonesOn(am)) mediaAttrs else alarmAttrs
        // Musiken pausas även i ljudlöst — som klockans larm (Niklas testade).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(soundAttrs)
                .setOnAudioFocusChangeListener { }
                .build()
            am.requestAudioFocus(focus!!)
        }
        if (am.ringerMode == AudioManager.RINGER_MODE_NORMAL) startBeep(soundAttrs)
        startVibration()
        openOverOtherApps()
        handler.postDelayed(timeout, RestAlarm.RING_MAX_MS)
        return START_NOT_STICKY
    }

    /// Används telefonen visar Android helskärmsnotisen bara som en liten notis.
    /// Med "Visa ovanpå andra appar" RITAR vi larmvyn som ett lager ovanpå det
    /// som är öppet (Niklas 2026-10-05: "ska ställa sig i vägen"). Ett lager, inte
    /// en ny skärm: att starta en skärm från bakgrunden stoppar Android även med
    /// behörigheten (b66). DISMISS/+30 tar bort lagret — man är kvar där man var.
    /// Tryck på rutan = appen öppnas (startas MEDAN lagret syns: ett synligt
    /// lager är det som låter Android släppa fram appen), sedan larmet av.
    /// Låst telefon: helskärmsnotisen visar RestAlarmActivity, inget lager.
    private var overlay: View? = null

    private fun openOverOtherApps() {
        if (!RestAlarm.wakeScreen(this) || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (!Settings.canDrawOverlays(this)) return
        if ((getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked) return
        try {
            val v = RestAlarmView.build(
                this,
                onSnooze = { RestAlarm.snooze(this) },
                onDismiss = { RestAlarm.dismiss(this) },
                onOpen = {
                    try {
                        RestAlarm.launchIntent(this)?.let { startActivity(it) }
                    } catch (_: Exception) {
                    }
                    RestAlarm.dismiss(this)
                },
            )
            val lp = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                PixelFormat.OPAQUE,
            )
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).addView(v, lp)
            overlay = v
        } catch (_: Exception) {
            overlay = null // notisen bär signalen ändå
        }
    }

    private fun closeOverlay() {
        val v = overlay ?: return
        overlay = null
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(v)
        } catch (_: Exception) {
        }
    }

    private fun startBeep(attrs: AudioAttributes) {
        try {
            player = MediaPlayer().apply {
                setAudioAttributes(attrs)
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
        closeOverlay()
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
