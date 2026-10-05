/// Vilotimerns larmmotor i Android (tool/android/kotlin/RestAlarm.kt) via en
/// MethodChannel. Ersätter flutter_local_notifications (bygge 58–62): notiser
/// kan bara dämpa musiken en kort stund — klockans beteende (musiken pausas
/// tills larmet stängs, larmvy över låsskärmen) kräver egen kod.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../theme/chain_theme.dart';
import 'rest_timer.dart';

class NativeRestAlarm implements RestAlarm {
  NativeRestAlarm({required this.look}) {
    _ch.setMethodCallHandler(_fromNative);
  }

  static const _ch = MethodChannel('the_chain/rest_alarm');

  /// Valt tema → larmvyns färger (ingen hex-väv där, Niklas 2026-10-05).
  ChainTheme look;

  bool _askedNotifications = false;
  void Function()? _onStopped;
  void Function(DateTime end)? _onSnoozed;

  Map<String, int> _colors() => {
        'background': look.background.toARGB32(),
        'accent': look.accent.toARGB32(),
        'textStrong': look.textStrong.toARGB32(),
        'textMuted': look.textMuted.toARGB32(),
        'borderStrong': look.borderStrong.toARGB32(),
      };

  @override
  Future<void> schedule(DateTime end, {bool wakeScreen = true}) async {
    try {
      // Android 13+: fråga om notiser första gången timern används.
      if (!_askedNotifications) {
        _askedNotifications = true;
        await _ch.invokeMethod<void>('requestNotifications');
      }
      await _ch.invokeMethod<void>('schedule', {
        'end': end.millisecondsSinceEpoch,
        'wake': wakeScreen,
        'look': _colors(),
      });
    } catch (e) {
      // Utan larm fungerar nedräkningen i appen ändå.
      debugPrint('rest alarm schedule: $e');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _ch.invokeMethod<void>('cancel');
    } catch (e) {
      debugPrint('rest alarm cancel: $e');
    }
  }

  @override
  Future<RestAlarmState?> state() async {
    try {
      final m = await _ch.invokeMapMethod<String, Object?>('state');
      if (m == null) return null;
      final end = (m['end'] as num?)?.toInt() ?? 0;
      return RestAlarmState(
        ringing: m['ringing'] == true,
        end: end > 0 ? DateTime.fromMillisecondsSinceEpoch(end) : null,
      );
    } catch (e) {
      debugPrint('rest alarm state: $e');
      return null;
    }
  }

  @override
  Future<bool?> requestWakeScreen() async {
    try {
      return await _ch.invokeMethod<bool>('requestWakeScreen');
    } catch (e) {
      debugPrint('rest alarm wake: $e');
      return null;
    }
  }

  @override
  Future<bool?> canWakeScreen() async {
    try {
      return await _ch.invokeMethod<bool>('canWakeScreen');
    } catch (e) {
      debugPrint('rest alarm canWake: $e');
      return null;
    }
  }

  @override
  void listen({required void Function() onStopped, required void Function(DateTime end) onSnoozed}) {
    _onStopped = onStopped;
    _onSnoozed = onSnoozed;
  }

  Future<void> _fromNative(MethodCall call) async {
    switch (call.method) {
      case 'stopped':
        _onStopped?.call();
      case 'snoozed':
        final ms = (call.arguments as num?)?.toInt();
        if (ms != null) _onSnoozed?.call(DateTime.fromMillisecondsSinceEpoch(ms));
    }
  }
}
