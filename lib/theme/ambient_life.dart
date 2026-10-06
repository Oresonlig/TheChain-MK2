/// Det som får temats bakgrund att leva med användaren (Niklas 2026-10-06,
/// Cosmic Horrors ådror):
///   * [roundProgress] — ådrorna växer med rundan: korta i början, fullvuxna
///     när rundan är klar, och drar sig tillbaka när en ny börjar. Räknas ur
///     kedjan (chain_screen) — samma på alla enheter, inget sparas.
///   * [burst] — LOG skickar en puls ut genom nätet och en liten gren spirar.
///     Bara den här körningen; en ny runda börjar om.
/// Teman som inte läser det här (Nanosuit) påverkas inte.
library;

import 'dart:math' as math;

class AmbientLife {
  AmbientLife._();

  static final Stopwatch _clock = Stopwatch()..start();
  static double _progress = 0;
  static int _sprouts = 0;
  static double? _shown;
  static int _lastMs = 0;
  static final List<int> _bursts = [];

  /// Rundans andel klar, 0–1. Ny runda (lägre värde) = groddarna nollställs.
  static set roundProgress(double p) {
    final v = p.clamp(0.0, 1.0);
    if (v < _progress) _sprouts = 0;
    _progress = v;
  }

  static double get roundProgress => _progress;

  /// Ett loggat set: en puls ut genom nätet + en liten tillväxt.
  static void burst() {
    final now = _clock.elapsedMilliseconds;
    _bursts.add(now);
    _bursts.removeWhere((t) => now - t > burstLife);
    if (_sprouts < maxSprouts) _sprouts++;
  }

  static const burstLife = 3200;
  static const maxSprouts = 14;

  /// Var nätet ska vara: 35 % vid rundans start, fullt när den är klar,
  /// plus groddarna från dagens LOG.
  static double get target => math.min(1.0, .35 + .65 * _progress + _sprouts * .012);

  /// Visad tillväxt — glider mot [target] (~2 s), så växten syns ske.
  /// [animated] false = hoppar direkt dit (minska rörelse).
  static double growth({required bool animated}) {
    final now = _clock.elapsedMilliseconds;
    final t = target;
    final s = _shown;
    if (!animated || s == null) {
      _lastMs = now;
      return _shown = t;
    }
    final dt = (now - _lastMs).clamp(0, 200) / 1000;
    _lastMs = now;
    return _shown = s + (t - s) * (1 - math.exp(-dt / .7));
  }

  /// Pågående pulser: ålder i ms (0 – [burstLife]).
  static Iterable<int> get burstAges {
    final now = _clock.elapsedMilliseconds;
    return _bursts.map((t) => now - t).where((a) => a >= 0 && a < burstLife);
  }

  /// Tester: börja om.
  static void reset() {
    _progress = 0;
    _sprouts = 0;
    _shown = null;
    _bursts.clear();
  }
}
