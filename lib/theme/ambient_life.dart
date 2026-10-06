/// Det som får temats bakgrund att svara på användaren (Niklas 2026-10-06,
/// Cosmic Horrors ådror): nätet är alltid fullvuxet ("jämfört med Nanosuit
/// jäkligt low key"), och varje LOG ([burst]) skickar en ljusvåg ut genom
/// det medan ådrorna sträcker ut sig en bit extra — och drar sig tillbaka
/// några sekunder senare. Inget sparas.
/// Teman som inte läser det här (Nanosuit) påverkas inte.
library;

import 'dart:math' as math;

class AmbientLife {
  AmbientLife._();

  static final Stopwatch _clock = Stopwatch()..start();
  static final List<int> _bursts = [];

  /// Ett loggat set.
  static void burst() {
    final now = _clock.elapsedMilliseconds;
    _bursts.add(now);
    _bursts.removeWhere((t) => now - t > burstLife);
  }

  /// Hur länge en LOG syns: vågen + utsträckningen och tillbakadragningen.
  static const burstLife = 5000;

  /// Nätets vanliga storlek (andel av hela nätet) — resten är LOG:ens räckvidd.
  static const rest = .82;

  /// Utsträckningen efter en LOG, 0–1: snabbt ut (~0,6 s), kvar en stund,
  /// sedan långsamt tillbaka.
  static double reach(int ageMs) {
    if (ageMs < 0 || ageMs >= burstLife) return 0;
    final t = ageMs / 1000;
    if (t < .6) return math.sin(t / .6 * math.pi / 2);
    if (t < 1.6) return 1;
    final back = (t - 1.6) / (burstLife / 1000 - 1.6);
    return .5 + .5 * math.cos(back * math.pi);
  }

  /// Visad storlek: [rest] plus den starkaste pågående utsträckningen.
  /// [animated] false (minska rörelse) = alltid [rest].
  static double growth({required bool animated}) {
    if (!animated) return rest;
    var extra = 0.0;
    for (final a in burstAges) {
      extra = math.max(extra, reach(a));
    }
    return rest + (1 - rest) * extra;
  }

  /// Pågående LOG:ar: ålder i ms (0 – [burstLife]).
  static Iterable<int> get burstAges {
    final now = _clock.elapsedMilliseconds;
    return _bursts.map((t) => now - t).where((a) => a >= 0 && a < burstLife);
  }

  /// Tester: börja om.
  static void reset() => _bursts.clear();
}
