/// Vilotimern. Startar när ett arbetsset loggas (om den är på i Settings), som
/// i MK1 — men signalen är en schemalagd Android-notis, så den kommer även när
/// appen ligger i bakgrunden (Instagram, Spotify) eller skärmen är släckt.
/// Sluttiden är absolut: nedräkningen överlever att appen pausas.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Signalen utanför appen (notiser i appen, fake i tester).
abstract class RestAlarm {
  /// Visar nedräkningen i notisfältet och schemalägger signalen vid [end].
  /// Ersätter en tidigare schemaläggning.
  Future<void> schedule(DateTime end);
  Future<void> cancel();
}

/// Ingen signal (tester, och om notiser inte går att starta).
class SilentRestAlarm implements RestAlarm {
  const SilentRestAlarm();
  @override
  Future<void> schedule(DateTime end) async {}
  @override
  Future<void> cancel() async {}
}

class RestTimer extends ChangeNotifier {
  RestTimer({RestAlarm? alarm, DateTime Function()? clock, this.tick = const Duration(milliseconds: 250)})
      : alarm = alarm ?? const SilentRestAlarm(),
        _now = clock ?? DateTime.now;

  final RestAlarm alarm;
  final DateTime Function() _now;
  final Duration tick;

  /// Hur länge "REST OVER" ligger kvar innan listen försvinner.
  static const doneHold = Duration(seconds: 3);
  static const step = Duration(seconds: 30);

  DateTime? _end;
  Timer? _ticker;

  bool get running => _end != null;

  /// Kvar i hela sekunder (avrundat uppåt; ≤ 0 = vilan är slut).
  int get remainingSecs {
    final e = _end;
    if (e == null) return 0;
    final ms = e.difference(_now()).inMilliseconds;
    return ms <= 0 ? (ms / 1000).floor() : (ms / 1000).ceil();
  }

  bool get done => running && remainingSecs <= 0;

  void start(int secs) {
    _end = _now().add(Duration(seconds: secs));
    _arm();
  }

  /// −30/+30. Under noll stoppas timern (inget att vila längre).
  void adjust(Duration d) {
    final e = _end;
    if (e == null) return;
    final next = e.add(d);
    if (!next.isAfter(_now())) {
      stop();
      return;
    }
    _end = next;
    _arm();
  }

  void stop() {
    if (_end == null) return;
    _end = null;
    _ticker?.cancel();
    _ticker = null;
    unawaited(alarm.cancel());
    notifyListeners();
  }

  void _arm() {
    unawaited(alarm.schedule(_end!));
    _ticker?.cancel();
    _ticker = Timer.periodic(tick, (_) => _onTick());
    notifyListeners();
  }

  void _onTick() {
    final e = _end;
    if (e == null) return;
    if (!_now().isBefore(e.add(doneHold))) {
      // Signalen är redan given av notisen; listen försvinner själv.
      _end = null;
      _ticker?.cancel();
      _ticker = null;
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
