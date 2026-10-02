/// Standardantal set när en övning läggs i ett pass — och BARA då (Gör om #4).
/// Reglerna är MK1:s (TAG_DEFAULTS, MEASURE_SET_DEFAULTS, getSetTargets):
/// förra passets antal följer med (max 8), annars schemats/mätsättets standard.
library;

import 'exercise.dart';
import 'history.dart';
import 'measure.dart';
import 'records.dart';

class SetCounts {
  const SetCounts(this.warmup, this.work);
  final int warmup;
  final int work;

  @override
  bool operator ==(Object other) => other is SetCounts && other.warmup == warmup && other.work == work;
  @override
  int get hashCode => Object.hash(warmup, work);
  @override
  String toString() => 'SetCounts($warmup, $work)';
}

const int maxCarriedSets = 8;

/// Standard utan historik. Schema först (ramp/singles), sedan unilateral, sedan mätsätt.
SetCounts baseCounts(Exercise e) {
  switch (e.scheme) {
    case SetScheme.ramp:
      return const SetCounts(0, 4);
    case SetScheme.singles:
      return const SetCounts(1, 5);
    case SetScheme.standard:
      if (e.unilateral) return const SetCounts(2, 1);
      return switch (e.measure) {
        Measure.weight => const SetCounts(2, 1), // HIT — "standard är HIT"
        Measure.bodyweight || Measure.repsOnly || Measure.carry => const SetCounts(0, 3),
        _ => const SetCounts(0, 1),
      };
  }
}

/// Antal set för en ny rad i passet. Ramp har ALDRIG uppvärmning, inte ens
/// från förra passet (MK1 3.75.0).
SetCounts defaultCounts(Exercise e, Iterable<HistoryEntry> history) {
  final base = baseCounts(e);
  final last = lastPerformance(history, e.id);
  final lastWork = last == null ? 0 : last.workSets.length.clamp(0, maxCarriedSets);
  final work = lastWork > 0 ? lastWork : base.work;
  if (e.scheme == SetScheme.ramp) return SetCounts(0, work);
  final warm = last == null ? base.warmup : last.warmupSets.length.clamp(0, maxCarriedSets);
  return SetCounts(warm, work < 1 ? 1 : work);
}
