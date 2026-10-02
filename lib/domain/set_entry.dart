/// Ett set i ett pass. Explicit lista per övning — inget fylls på eller skalas
/// av automatiskt efter att övningen lagts i passet (Gör om #4).
library;

import 'ids.dart';

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
}

class SetEntry {
  const SetEntry({
    required this.id,
    required this.kind,
    this.values = SetValues.empty,
    this.isLogged = false,
    this.failed = false,
    this.side,
    this.bodyweightKg,
  });

  final SetId id;
  final SetKind kind;
  final SetValues values;

  /// Användaren har tryckt Log. Bara loggade set hamnar i historik och PR.
  final bool isLogged;

  /// Missat mål. Räknas aldrig som PR.
  final bool failed;

  /// Unilaterala övningar: vilken sida.
  final Side? side;

  /// Kroppsvikt när settet loggades (för mätsätt med kroppsvikt + extra).
  final double? bodyweightKg;

  SetEntry copyWith({
    SetValues? values,
    bool? isLogged,
    bool? failed,
    Side? side,
    double? bodyweightKg,
  }) =>
      SetEntry(
        id: id,
        kind: kind,
        values: values ?? this.values,
        isLogged: isLogged ?? this.isLogged,
        failed: failed ?? this.failed,
        side: side ?? this.side,
        bodyweightKg: bodyweightKg ?? this.bodyweightKg,
      );
}
