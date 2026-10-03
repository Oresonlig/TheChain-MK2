/// Ett set i ett pass. Explicit lista per övning — inget fylls på eller skalas
/// av automatiskt efter att övningen lagts i passet (Gör om #4).
library;

import 'ids.dart';
import 'measure.dart';

enum SetKind { warmup, work }

enum Side { left, right }

/// Inmatade värden. Samma fält används för det som skrivs och det som loggas
/// (MK1 hade inputBuffer, loggedSets och savedExercises — Gör om #5).
class SetValues {
  const SetValues({
    this.weight,
    this.extra,
    this.reps,
    this.forcedReps,
    this.secs,
    this.dist,
    this.distM,
    this.sprints,
    this.incline,
    this.temp,
  });

  final double? weight; // kg
  final double? extra; // kg utöver kroppsvikt
  final int? reps;
  final int? forcedReps;
  final int? secs;
  final double? dist; // km
  final double? distM; // meter (carry)
  final int? sprints;
  final double? incline; // %
  final double? temp; // °C

  static const empty = SetValues();

  num? field(SetField f) => switch (f) {
        SetField.weight => weight,
        SetField.extra => extra,
        SetField.reps => reps,
        SetField.secs => secs,
        SetField.dist => dist,
        SetField.distM => distM,
        SetField.sprints => sprints,
        SetField.incline => incline,
        SetField.temp => temp,
      };
}

class SetEntry {
  const SetEntry({
    required this.id,
    required this.kind,
    this.values = SetValues.empty,
    this.target,
    this.isLogged = false,
    this.excludeFromRecords = false,
    this.side,
    this.bodyweightKg,
  });

  final SetId id;
  final SetKind kind;

  /// Det som faktiskt utfördes. PR räknas alltid på detta.
  final SetValues values;

  /// Satt = användaren har tryckt FAIL. Målet är valfritt ("4 reps", "90 s"):
  /// tomt mål = missat utan angivet mål (✗), mål 4 med 3 utförda = "3/4 ✗".
  /// PR räknas ändå alltid på det utförda — 100 kg × 3 är 100 kg × 3
  /// (beslut 2026-10-02, bekräftat 2026-10-03).
  final SetValues? target;

  /// Användaren har tryckt Log. Bara loggade set hamnar i historik och PR.
  final bool isLogged;

  /// Räknas aldrig i PR. Används för MK1:s gamla fail-set (importeras orörda,
  /// "lagt kort ligger") och kan bli ett eget val i UI:t.
  final bool excludeFromRecords;

  /// Unilaterala övningar: vilken sida.
  final Side? side;

  /// Kroppsvikt när settet loggades (för mätsätt med kroppsvikt + extra).
  final double? bodyweightKg;

  /// Missat = FAIL tryckt utan mål, eller något mätt fält nådde inte sitt mål.
  bool missed(Measure m) {
    final t = target;
    if (t == null) return false;
    var hasGoal = false;
    for (final f in m.fields) {
      final goal = t.field(f);
      if (goal == null) continue;
      hasGoal = true;
      final got = values.field(f);
      if (got == null || got < goal) return true;
    }
    return !hasGoal;
  }

  /// copyWith kan inte nollställa fält — de två som kan bli null igen har egna.
  SetEntry withTarget(SetValues? t) => SetEntry(
        id: id,
        kind: kind,
        values: values,
        target: t,
        isLogged: isLogged,
        excludeFromRecords: excludeFromRecords,
        side: side,
        bodyweightKg: bodyweightKg,
      );

  SetEntry withSide(Side? s) => SetEntry(
        id: id,
        kind: kind,
        values: values,
        target: target,
        isLogged: isLogged,
        excludeFromRecords: excludeFromRecords,
        side: s,
        bodyweightKg: bodyweightKg,
      );

  SetEntry copyWith({
    SetValues? values,
    SetValues? target,
    bool? isLogged,
    bool? excludeFromRecords,
    Side? side,
    double? bodyweightKg,
  }) =>
      SetEntry(
        id: id,
        kind: kind,
        values: values ?? this.values,
        target: target ?? this.target,
        isLogged: isLogged ?? this.isLogged,
        excludeFromRecords: excludeFromRecords ?? this.excludeFromRecords,
        side: side ?? this.side,
        bodyweightKg: bodyweightKg ?? this.bodyweightKg,
      );
}
