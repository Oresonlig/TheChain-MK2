/// PR-motorn och "förra gången" — EN motor över historiken (Gör om #7).
/// MK1 hade samma loop på tre ställen (getAllPRs, buildPRMap,
/// getExerciseProgression) plus importerade PR som specialfall.
library;

import 'history.dart';
import 'ids.dart';
import 'measure.dart';
import 'set_entry.dart';
import 'workout.dart';

class PersonalRecord {
  const PersonalRecord({
    required this.exerciseId,
    required this.measure,
    required this.set,
    required this.date,
    required this.value,
    required this.tiebreak,
    required this.source,
  });

  final ExerciseId exerciseId;
  final Measure measure;
  final SetEntry set;
  final DateTime date;
  final double value;
  final double tiebreak;

  /// Importerade resultat konkurrerar på lika villkor (beslut 4).
  final EntrySource source;
}

class ProgressionPoint {
  const ProgressionPoint({required this.date, required this.value, required this.isPr});

  final DateTime date;
  final double value;

  /// Nytt all-time-high i serien vid den här punkten.
  final bool isPr;
}

class LastPerformance {
  const LastPerformance({required this.date, required this.exercise});

  final DateTime date;
  final WorkoutExercise exercise;

  List<SetEntry> get workSets =>
      exercise.sets.where((s) => s.kind == SetKind.work && s.isLogged).toList();
  List<SetEntry> get warmupSets =>
      exercise.sets.where((s) => s.kind == SetKind.warmup && s.isLogged).toList();
}

/// Övningar i avslutade pass som räknas: ej överhoppade, nyast först.
Iterable<(DateTime, EntrySource, WorkoutExercise)> _performed(
  Iterable<HistoryEntry> history,
  ExerciseId? only,
) sync* {
  final entries = history.whereType<WorkoutEntry>().toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  for (final e in entries) {
    for (final ex in e.workout.exercises) {
      if (ex.status == ExerciseStatus.skipped) continue;
      if (only != null && ex.exerciseId != only) continue;
      yield (e.date, e.source, ex);
    }
  }
}

/// Bästa arbetsset enligt mätsättets PR-regel: högst värde, sedan tiebreak.
/// Uppvärmning räknas aldrig.
(SetEntry, double, double)? bestSet(Measure m, Iterable<SetEntry> sets, {double? Function(SetEntry)? valueOf}) {
  (SetEntry, double, double)? best;
  for (final s in sets) {
    if (s.kind != SetKind.work) continue;
    final v = (valueOf ?? m.prValue)(s);
    if (v == null) continue;
    final tb = m.prTiebreak(s);
    if (best == null || v > best.$2 || (v == best.$2 && tb > best.$3)) best = (s, v, tb);
  }
  return best;
}

/// PR per övning. [hidden] = övningar användaren dolt (MK1 "ignore PR", nu per id).
/// Vid helt lika värde och tiebreak vinner det äldsta — det sattes först.
Map<ExerciseId, PersonalRecord> personalRecords(
  Iterable<HistoryEntry> history, {
  Set<ExerciseId> hidden = const {},
}) {
  final out = <ExerciseId, PersonalRecord>{};
  for (final (date, source, ex) in _performed(history, null)) {
    if (hidden.contains(ex.exerciseId)) continue;
    final b = bestSet(ex.measure, ex.sets);
    if (b == null) continue;
    final (set, v, tb) = b;
    final cur = out[ex.exerciseId];
    final better = cur == null ||
        v > cur.value ||
        (v == cur.value && tb > cur.tiebreak) ||
        (v == cur.value && tb == cur.tiebreak && date.isBefore(cur.date));
    if (better) {
      out[ex.exerciseId] = PersonalRecord(
        exerciseId: ex.exerciseId,
        measure: ex.measure,
        set: set,
        date: date,
        value: v,
        tiebreak: tb,
        source: source,
      );
    }
  }
  return out;
}

/// Värdet som plottas. Kroppsviktsmätsätt visar bara tillagd vikt, så att en
/// viktnedgång inte ser ut som styrketapp (MK1 3.78.6).
double? progressionValue(Measure m, SetEntry s) {
  if (m.pr == PrMetric.extra) {
    return (!s.isLogged || s.failed || s.values.extra == null) ? null : s.values.extra;
  }
  return m.prValue(s);
}

/// En punkt per pass där övningen loggats, äldst först.
List<ProgressionPoint> progression(Iterable<HistoryEntry> history, ExerciseId id) {
  final rows = _performed(history, id).toList().reversed;
  final out = <ProgressionPoint>[];
  double? high;
  for (final (date, _, ex) in rows) {
    final b = bestSet(ex.measure, ex.sets, valueOf: (s) => progressionValue(ex.measure, s));
    if (b == null) continue;
    final v = b.$2;
    final isPr = high == null || v > high;
    if (isPr) high = v;
    out.add(ProgressionPoint(date: date, value: v, isPr: isPr));
  }
  return out;
}

/// Senaste passet där övningen har minst ett loggat arbetsset.
LastPerformance? lastPerformance(Iterable<HistoryEntry> history, ExerciseId id) {
  for (final (date, _, ex) in _performed(history, id)) {
    final hasWork = ex.sets.any((s) => s.kind == SetKind.work && s.isLogged);
    if (hasWork) return LastPerformance(date: date, exercise: ex);
  }
  return null;
}
