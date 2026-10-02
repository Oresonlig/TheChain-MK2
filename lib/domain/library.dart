/// Övningsbiblioteket, portat från MK1:s EXERCISE_LIBRARY (index.html).
/// Id:n är EXAKT MK1:s exId (`ex_` + slug av namnet) så att historik, PR och
/// justeringar kopplas ihop när MK1-data läses in (mk1_codec).
library;

import 'exercise.dart';
import 'ids.dart';
import 'measure.dart';

/// MK1:s slugifyExId: gemener, allt utom a–z/0–9 blir `_`, trimmat, prefix `ex_`.
ExerciseId exerciseIdFromName(String name) {
  final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return ExerciseId('ex_$slug');
}

Exercise _e(
  String name,
  MuscleGroup group, {
  Measure measure = Measure.weight,
  bool unilateral = false,
  String? tip,
}) =>
    Exercise(
      id: exerciseIdFromName(name),
      name: name,
      group: group,
      measure: measure,
      unilateral: unilateral,
      tip: tip,
    );

const _chest = MuscleGroup.chest, _back = MuscleGroup.back, _shoulders = MuscleGroup.shoulders;
const _arms = MuscleGroup.arms, _legs = MuscleGroup.legs, _traps = MuscleGroup.traps;
const _core = MuscleGroup.core, _cardio = MuscleGroup.cardio;

/// Set-schema (ramp/singles) sätts inte här: i MK1 kom ramp från programmets
/// platser och användarens taggar — i MK2 blir det användarens justering per övning.
final List<Exercise> exerciseLibrary = List.unmodifiable([
  // CHEST
  _e('Bench Press (BB)', _chest),
  _e('Bench Press (DB)', _chest),
  _e('Cable Crossover', _chest),
  _e('Chest Dips', _chest, measure: Measure.bodyweight),
  _e('Decline Flyes (Cable)', _chest),
  _e('Decline Press (Cable)', _chest),
  _e('Decline Press (DB)', _chest),
  _e('Decline Press (Smith)', _chest),
  _e('Flyes (Cable)', _chest, tip: 'Full ROM - Deep stretch'),
  _e('Flyes (DB)', _chest, tip: "Flat bench - Deep stretch, don't overload"),
  _e('Hammer Strength Press', _chest),
  _e('Incline Flyes (Cable)', _chest),
  _e('Incline Press (BB)', _chest),
  _e('Incline Press (DB)', _chest),
  _e('Incline Press (Smith)', _chest),
  _e('Pec Deck', _chest),
  _e('Seated Flyes (Cable)', _chest),
  _e('Single-Arm Flyes (Cable)', _chest, unilateral: true),
  _e('Standing Flyes (Cable)', _chest),
  // BACK
  _e('Back Extension', _back, measure: Measure.bodyweight),
  _e('Bentover Row', _back),
  _e('Chins (supinated)', _back, measure: Measure.bodyweight),
  _e('Close-grip Pulldown', _back),
  _e('Deadlift', _back),
  _e('Incline Bench Cable Pullover', _back, tip: 'Deep lat stretch — full ROM, no triceps or grip'),
  _e('Jefferson Deadlift', _back),
  _e('Lat Prayers', _back),
  _e('Neutral Grip Pull-ups', _back, measure: Measure.bodyweight),
  _e('Power Clean', _back),
  _e('Power Clean + Shoulder Press', _back),
  _e('Pull-ups (pronated)', _back, measure: Measure.bodyweight),
  _e('Rack Pull', _back),
  _e('Seated Row (Cable)', _back),
  _e('Seated Row (Machine)', _back),
  _e('Straight-arm Pulldown', _back),
  _e('T-bar Row', _back),
  _e('Unilateral Row (Cable)', _back, unilateral: true),
  _e('Wide-grip Pulldown', _back),
  // SHOULDERS
  _e('Arnold Press', _shoulders),
  _e('Band Pull-apart', _shoulders),
  _e('External Rotator Cuff', _shoulders),
  _e('Face Pulls', _shoulders),
  _e('Face Pulls (external rotation)', _shoulders),
  _e('Front Raise (Cable)', _shoulders),
  _e('Helms Rear Delt Row', _shoulders),
  _e('Internal Rotator Cuff', _shoulders),
  _e('Lateral Raises (Cable)', _shoulders),
  _e('Lateral Raises (DB)', _shoulders),
  _e('Military Press (BB)', _shoulders),
  _e('Military Press (Smith)', _shoulders),
  _e('Rear Delt Flyes (Cable)', _shoulders),
  _e('Rear Delt Flyes (DB)', _shoulders),
  _e('Shoulder Press (DB)', _shoulders),
  _e('Upright Row', _shoulders),
  // ARMS
  _e('Biceps Curl (BB)', _arms),
  _e('Biceps Curl (Cable)', _arms),
  _e('Biceps Curl (DB)', _arms),
  _e('Close-Grip Bench', _arms),
  _e('Hammer Curl', _arms),
  _e('Incline Biceps Curl (Cable)', _arms, tip: 'Deep biceps stretch — let the arms hang back'),
  _e('Incline Biceps Curl (DB)', _arms, tip: 'Deep biceps stretch — let the arms hang back'),
  _e('Overhead Tricep Extension', _arms),
  _e('Preacher Curl (DB)', _arms, unilateral: true),
  _e('Preacher Curl (EZ)', _arms),
  _e('Skull Crushers', _arms),
  _e('Spider Curl', _arms),
  _e('Tricep Dips', _arms, measure: Measure.bodyweight),
  _e('Tricep Pushdowns', _arms),
  // LEGS
  _e('Back Squat', _legs),
  _e('Bulgarian Split Squat', _legs),
  _e('Front Squat', _legs),
  _e('Hack Squat', _legs),
  _e('Leg Extension', _legs),
  _e('Leg Press', _legs),
  _e('Lying Leg Curl', _legs),
  _e('Nordic Curl', _legs, measure: Measure.repsOnly),
  _e('Romanian Deadlift', _legs),
  _e('Seated Calf Raise', _legs),
  _e('Seated Leg Curl', _legs),
  _e('Standing Calf Raise', _legs),
  _e('Zercher Squat', _legs),
  // TRAPS
  _e('Shrugs (BB)', _traps),
  _e('Shrugs (DB)', _traps),
  _e('Shrugs (Trap Bar)', _traps),
  // CORE
  _e('Ab Wheel', _core, measure: Measure.repsOnly),
  _e('Cable Crunch', _core),
  _e('Crunches', _core, measure: Measure.repsOnly),
  _e('Dead Bug', _core, measure: Measure.repsOnly),
  _e('Dragon Flag', _core, measure: Measure.repsOnly),
  _e('Hanging Leg Raise', _core, measure: Measure.repsOnly),
  _e('Plank', _core, measure: Measure.timed),
  _e('Sit-ups', _core, measure: Measure.repsOnly),
  // CARDIO / CONDITIONING
  _e('Assault Bike', _cardio, measure: Measure.cardioSprint),
  _e('Bike Cardio', _cardio, measure: Measure.cardio, tip: '20 min steady state'),
  _e('Dead Hang', _cardio, measure: Measure.bodyweightTimed, tip: 'Supinated or neutral'),
  _e('Farmers Walk', _cardio, measure: Measure.carry),
  _e('Incline Walk', _cardio, measure: Measure.inclineCardio, tip: 'Treadmill incline'),
  _e('Running', _cardio, measure: Measure.run),
  _e('Running with Sprints', _cardio, measure: Measure.runSprint, tip: 'Sprint count is logged, pace is the PR'),
  _e('Sauna', _cardio, measure: Measure.sauna),
  _e('Sled Push', _cardio, measure: Measure.carry),
  _e('Walk', _cardio, measure: Measure.cardio),
]);

final Map<ExerciseId, Exercise> _byId = {for (final e in exerciseLibrary) e.id: e};

Exercise? libraryExercise(ExerciseId id) => _byId[id];

/// Uppslag för pass och vyer: egna övningar först, sedan biblioteket, med
/// användarens justeringar applicerade.
Exercise? resolveExercise(
  ExerciseId id, {
  Map<ExerciseId, Exercise> custom = const {},
  Map<ExerciseId, ExerciseOverride> overrides = const {},
}) {
  final base = custom[id] ?? _byId[id];
  if (base == null) return null;
  final o = overrides[id];
  return o == null ? base : o.applyTo(base);
}
