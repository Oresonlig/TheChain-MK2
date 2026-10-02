/// Mätsätt = sluten enum, data per övning (Behåll). Speglar MK1:s `MEASURES`
/// (index.html / src/measures.js) i sak; Dart-kompilatorn kontrollerar att
/// varje `switch` täcker alla fall.
library;

import 'set_entry.dart';

/// Ett inmatningsfält. Allt lagras metriskt: kg, sekunder, km, meter, °C, %.
enum SetField { weight, extra, reps, secs, dist, distM, sprints, incline, temp }

/// Vad som jämförs för PR. Alltid "högre vinner" — pace lagras därför som km/h.
enum PrMetric { weight, extra, reps, secs, dist, sprints, pace }

enum Measure {
  weight([SetField.weight, SetField.reps], PrMetric.weight, forcedReps: true),
  bodyweight([SetField.extra, SetField.reps], PrMetric.extra,
      forcedReps: true, usesBodyweight: true),
  repsOnly([SetField.reps], PrMetric.reps, forcedReps: true),
  timed([SetField.secs], PrMetric.secs, forcedReps: true),
  bodyweightTimed([SetField.extra, SetField.secs], PrMetric.secs,
      forcedReps: true, usesBodyweight: true),
  cardio([SetField.secs, SetField.dist], PrMetric.dist, minutesInput: true),
  cardioSprint([SetField.secs, SetField.dist, SetField.sprints], PrMetric.sprints),
  run([SetField.secs, SetField.dist], PrMetric.pace, minutesInput: true),
  runSprint([SetField.secs, SetField.dist, SetField.sprints], PrMetric.pace,
      minutesInput: true),
  carry([SetField.weight, SetField.distM], PrMetric.weight),
  inclineCardio([SetField.incline, SetField.secs, SetField.dist], PrMetric.dist,
      minutesInput: true),
  sauna([SetField.temp, SetField.secs], PrMetric.secs, minutesInput: true);

  const Measure(
    this.fields,
    this.pr, {
    this.forcedReps = false,
    this.usesBodyweight = false,
    this.minutesInput = false,
  });

  /// Fälten i visningsordning.
  final List<SetField> fields;
  final PrMetric pr;

  /// Om forcerade reps (+F) är meningsfulla.
  final bool forcedReps;

  /// Kroppsvikt + extra last; kroppsvikten ögonblicksfångas i settet.
  final bool usesBodyweight;

  /// Tiden matas in och visas i minuter (lagras alltid i sekunder).
  final bool minutesInput;

  /// PR-värdet för ett set, eller null om settet inte kan bära en PR.
  /// Failade och ej loggade set räknas aldrig.
  double? prValue(SetEntry s) {
    if (!s.isLogged || s.failed) return null;
    final v = s.values;
    return switch (pr) {
      PrMetric.weight => v.weight,
      PrMetric.extra => v.extra == null ? null : v.extra! + (s.bodyweightKg ?? 0),
      PrMetric.reps => v.reps?.toDouble(),
      PrMetric.secs => v.secs?.toDouble(),
      PrMetric.dist => v.dist,
      PrMetric.sprints => v.sprints?.toDouble(),
      // km/h, så att "högre vinner" gäller även löpning (MK1 3.84.0).
      PrMetric.pace => (v.dist != null && v.dist! > 0 && v.secs != null && v.secs! > 0)
          ? v.dist! / (v.secs! / 3600)
          : null,
    };
  }

  /// Avgör lika PR-värden: fler reps, mer vikt vid lika tid, längre sträcka vid lika pace.
  double prTiebreak(SetEntry s) {
    final v = s.values;
    return switch (pr) {
      PrMetric.weight || PrMetric.extra => (v.reps ?? 0).toDouble(),
      PrMetric.secs => (v.weight ?? 0) + (v.extra ?? 0),
      PrMetric.pace => v.dist ?? 0,
      PrMetric.reps || PrMetric.dist || PrMetric.sprints => 0,
    };
  }
}
