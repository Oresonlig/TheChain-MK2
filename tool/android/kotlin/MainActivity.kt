// Ersätter Flutters genererade MainActivity (configure_android.mjs): samma
// FlutterActivity + kanalen till vilotimerns larmmotor (RestAlarm.kt).
package com.oresonlig.the_chain

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "the_chain/rest_alarm")
        RestAlarm.channel = ch
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "schedule" -> {
                        val end = (call.argument<Number>("end") ?: 0).toLong()
                        val wake = call.argument<Boolean>("wake") ?: true
                        val look = call.argument<Map<String, Number>>("look")?.mapValues { it.value.toInt() }
                        RestAlarm.schedule(applicationContext, end, wake, look)
                        result.success(null)
                    }
                    "cancel" -> {
                        RestAlarm.cancel(applicationContext)
                        result.success(null)
                    }
                    "state" -> result.success(RestAlarm.state(applicationContext))
                    "requestNotifications" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 71)
                        }
                        result.success(null)
                    }
                    "requestWakeScreen" -> {
                        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && !nm.canUseFullScreenIntent()) {
                            startActivity(
                                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName")),
                            )
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("rest_alarm", e.message, null)
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        RestAlarm.channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
