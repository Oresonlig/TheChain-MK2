/// Vilotimern. Startar när ett arbetsset loggas (om den är på i Settings), som
/// i MK1. Signalen vid noll är en egen larmmotor i Android (som klockans larm,
/// Niklas 2026-10-05): pip i loop, musiken pausas, skärmen tänds med en liten
/// larmvy över låsskärmen — DISMISS / +30 S, tystnar själv efter 60 s.
/// Sluttiden är absolut: nedräkningen överlever att appen pausas.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Larmmotorns läge (för att synka när appen syns igen).
class RestAlarmState {
  const RestAlarmState({required this.ringing, this.end});
  final bool ringing;

  /// Schemalagd sluttid, eller null om ingen vila pågår.
  final DateTime? end;
}

/// Signalen utanför appen (Android i appen, fake i tester).
abstract class RestAlarm {
  /// Nedräkning i notisfältet + larm vid [end]. Ersätter en tidigare vila och
  /// tystar ett larm som ringer. [wakeScreen] = skärmen tänds (larmvyn).
  Future<void> schedule(DateTime end, {bool wakeScreen = true});

  /// Ingen vila längre: tar bort larm, nedräkning och ett larm som ringer.
  Future<void> cancel();

  Future<RestAlarmState?> state();

  /// Behörigheten att tända skärmen. true = given, false/null = inte given.
  Future<bool?> requestWakeScreen();

  /// Larmet avfärdades / fick +30 utanför appen (larmvyn, notisens knappar).
  void listen({required void Function() onStopped, required void Function(DateTime end) onSnoozed});
}

/// Ingen signal (tester, och om larmmotorn inte finns).
class SilentRestAlarm implements RestAlarm {
  const SilentRestAlarm();
  @override
  Future<void> schedule(DateTime end, {bool wakeScreen = true}) async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<RestAlarmState?> state() async => null;
  @override
  Future<bool?> requestWakeScreen() async => null;
  @override
  void listen({required void Function() onStopped, required void Function(DateTime end) onSnoozed}) {}
}

class RestTimer extends ChangeNotifier {
  RestTimer({RestAlarm? alarm, DateTime Function()? clock, this.tick = const Duration(milliseconds: 250)})
      : alarm = alarm ?? const SilentRestAlarm(),
        _now = clock ?? DateTime.now {
    this.alarm.listen(onStopped: _remoteStopped, onSnoozed: _remoteSnoozed);
  }

  final RestAlarm alarm;
  final DateTime Function() _now;
  final Duration tick;

  /// Larmet tystnar självt efter 60 s (RestAlarm.kt) — listen följer med.
  static const ringMax = Duration(seconds: 60);
  static const step = Duration(seconds: 30);

  DateTime? _end;
  Timer? _ticker;
  bool _wakeScreen = true;

  bool get running => _end != null;

  /// Kvar i hela sekunder (avrundat uppåt; ≤ 0 = vilan är slut).
  int get remainingSecs {
    final e = _end;
    if (e == null) return 0;
    final ms = e.difference(_now()).inMilliseconds;
    return ms <= 0 ? (ms / 1000).floor() : (ms / 1000).ceil();
  }

  /// Vilan är slut och larmet ringer (REST OVER + DISMISS / +30).
  bool get done => running && remainingSecs <= 0;

  void start(int secs, {bool wakeScreen = true}) {
    _wakeScreen = wakeScreen;
    _end = _now().add(Duration(seconds: secs));
    _arm();
  }

  /// −30/+30 under vilan. Under noll stoppas timern. När larmet ringer ger +30
  /// en ny vila på 30 s från nu (som larmvyns +30 S).
  void adjust(Duration d) {
    final e = _end;
    if (e == null) return;
    if (done) {
      if (d > Duration.zero) start(d.inSeconds, wakeScreen: _wakeScreen);
      return;
    }
    final next = e.add(d);
    if (!next.isAfter(_now())) {
      stop();
      return;
    }
    _end = next;
    _arm();
  }

  /// ✕ / DISMISS: tystar larmet och tar bort vilan.
  void stop() {
    if (_end == null) return;
    _clear();
    unawaited(alarm.cancel());
  }

  /// Appen syns igen: larmmotorn kan ha avfärdats eller fått +30 medan appen
  /// låg i bakgrunden (eller Flutter startats om).
  Future<void> appResumed() async {
    final s = await alarm.state();
    if (s == null) return;
    final e = s.end;
    if (s.ringing) {
      // REST OVER visas tills det avfärdas (även om appen startats om under larmet).
      if (!running) {
        _end = e ?? _now();
        _startTicker();
        notifyListeners();
      }
      return;
    }
    if (e == null || !e.isAfter(_now())) {
      if (running) _clear();
    } else if (e != _end) {
      _end = e;
      _startTicker();
      notifyListeners();
    }
  }

  void _remoteStopped() {
    if (running) _clear();
  }

  void _remoteSnoozed(DateTime end) {
    _end = end;
    _startTicker();
    notifyListeners();
  }

  void _clear() {
    _end = null;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void _arm() {
    unawaited(alarm.schedule(_end!, wakeScreen: _wakeScreen));
    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(tick, (_) => _onTick());
  }

  void _onTick() {
    final e = _end;
    if (e == null) return;
    // Säkerhetsnät om larmmotorns besked uteblir: följ dess 60 s.
    if (!_now().isBefore(e.add(ringMax + const Duration(seconds: 2)))) {
      _clear();
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Vilotidens gränser i Settings (fri tid, Niklas 2026-10-05).
const kMinRestSecs = 10;
const kMaxRestSecs = 600;
int clampRestSecs(int s) => s.clamp(kMinRestSecs, kMaxRestSecs);

/// Inställningens visning: "0:45", "1:30" …
String fmtRestChoice(int secs) => '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';

/// "1:45" / "45s" (som MK1).
String fmtRest(int secs) {
  final s = secs < 0 ? 0 : secs;
  final m = s ~/ 60;
  final r = s % 60;
  return m > 0 ? '$m:${r.toString().padLeft(2, '0')}' : '${r}s';
}
