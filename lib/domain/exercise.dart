/// Övningskatalogen: ett id per övning, bibliotek och egna i samma form
/// (Gör om #2). MK1:s taggar delas upp i tre oberoende egenskaper (Gör om #3).
library;

import 'ids.dart';
import 'measure.dart';

enum MuscleGroup { arms, back, cardio, chest, core, legs, shoulders, traps, other }

/// Hur seten struktureras när övningen läggs i ett pass.
/// Påverkar bara standardvärdet — aldrig redan skapade set.
enum SetScheme {
  /// Uppvärmning + arbetsset (MK1:s HIT-standard).
  standard,

  /// Ökande vikt varje set, inga separata uppvärmningsset.
  ramp,

  /// Tunga singlar.
  singles,
}

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.group,
    required this.measure,
    this.scheme = SetScheme.standard,
    this.unilateral = false,
    this.tip,
    this.isCustom = false,
  });

  final ExerciseId id;
  final String name;
  final MuscleGroup group;
  final Measure measure;
  final SetScheme scheme;

  /// En sida i taget; ger L/R-spårning.
  final bool unilateral;

  /// Teknik-cue som följer övningen (inte platsen).
  final String? tip;

  /// Skapad av användaren.
  final bool isCustom;
}

/// Användarens egna justeringar av en biblioteksövning. Nycklas på övningens id,
/// så de följer övningen genom byten (MK1 3.76.0).
class ExerciseOverride {
  const ExerciseOverride({this.measure, this.scheme, this.unilateral});

  final Measure? measure;
  final SetScheme? scheme;
  final bool? unilateral;

  Exercise applyTo(Exercise e) => Exercise(
        id: e.id,
        name: e.name,
        group: e.group,
        measure: measure ?? e.measure,
        scheme: scheme ?? e.scheme,
        unilateral: unilateral ?? e.unilateral,
        tip: e.tip,
        isCustom: e.isCustom,
      );
}
