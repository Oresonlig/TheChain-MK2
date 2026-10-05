/// Vilotimerns signal på Android: en tyst nedräkning i notisfältet medan man
/// vilar + en schemalagd notis (ljud + vibration, respekterar tyst läge) vid
/// noll. Exakt larm via USE_EXACT_ALARM (configure_android.mjs) — ingen
/// butik, så ingen granskning av behörigheten.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'rest_timer.dart';

class NotificationRestAlarm implements RestAlarm {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _asked = false;

  static const _countdownId = 7001;
  static const _doneId = 7002;
  static const _doneChannel = 'rest_alert';

  Future<bool> _init() async {
    if (_ready) return true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
      _ready = true;
      // Den gamla, lilla kanalen (bygge 58–59) ska inte ligga kvar i telefonens notisinställningar.
      await _android?.deleteNotificationChannel(channelId: 'rest_done');
    } catch (e) {
      debugPrint('rest alarm init: $e');
    }
    return _ready;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> schedule(DateTime end) async {
    if (!await _init()) return;
    try {
      // Android 13+: fråga om notiser första gången timern används.
      if (!_asked) {
        _asked = true;
        await _android?.requestNotificationsPermission();
      }
      final now = DateTime.now();
      final left = end.difference(now);
      if (left <= Duration.zero) return;
      await _plugin.cancel(id: _doneId);
      await _plugin.show(
        id: _countdownId,
        title: 'Resting',
        body: 'Next set when the timer hits zero',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_countdown',
            'Rest timer countdown',
            channelDescription: 'Silent countdown while you rest',
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            enableVibration: false,
            silent: true,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: true,
            when: end.millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: true,
            timeoutAfter: left.inMilliseconds,
            category: AndroidNotificationCategory.stopwatch,
          ),
        ),
      );
      await _plugin.zonedSchedule(
        id: _doneId,
        scheduledDate: tz.TZDateTime.from(end, tz.UTC),
        title: 'Rest over',
        body: 'Next set!',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            // Kanalens ljud/prioritet låses av Android när den skapats — ny
            // kanal i stället för den lilla 'rest_done' (Niklas 2026-10-05).
            _doneChannel,
            'Rest timer alert',
            channelDescription: 'Beeps, vibrates and wakes the screen when the rest is over',
            importance: Importance.max,
            priority: Priority.max,
            // Notisljud, inte larm: ljudlöst/vibration respekteras (Niklas).
            sound: const RawResourceAndroidNotificationSound('rest_beep'),
            vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
            category: AndroidNotificationCategory.alarm,
            // Tänder skärmen och visar appen över låsskärmen; i en annan app
            // blir det en stor notis överst.
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
            timeoutAfter: const Duration(minutes: 2).inMilliseconds,
          ),
        ),
      );
    } catch (e) {
      // Utan signal fungerar nedräkningen i appen ändå.
      debugPrint('rest alarm schedule: $e');
    }
  }

  @override
  Future<void> cancel() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _countdownId);
      await _plugin.cancel(id: _doneId);
    } catch (e) {
      debugPrint('rest alarm cancel: $e');
    }
  }
}
