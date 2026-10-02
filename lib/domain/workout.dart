/// Ett pass som pågår eller är avslutat (Gör om #5). Synkas mellan enheter
/// även medan det pågår (beslut 2026-10-02).
library;

import 'ids.dart';
import 'set_entry.dart';

enum ExerciseStatus { open, done, skipped }

class WorkoutExercise {
  const WorkoutExercise({
    required this.exerciseId,
    this.slotId,
    this.temporarySwapFrom,
    this.status = ExerciseStatus.open,
    this.sets = const [],
  });

  /// Övningen som faktiskt körs.
  final ExerciseId exerciseId;

  /// Platsen i programmet; null = extraövning "bara idag".
  final SlotId? slotId;

  /// Satt vid tillfälligt byte: övningen som platsen normalt har.
  /// Programmet ändras inte (permanent byte = Slot.originalExerciseId).
  final ExerciseId? temporarySwapFrom;

  final ExerciseStatus status;

  /// Explicit lista. Skapas med standardantal när övningen läggs till,
  /// ändras sedan bara av användaren.
  final List<SetEntry> sets;

  bool get isExtra => slotId == null;
}

class Workout {
  const Workout({
    required this.id,
    required this.sessionId,
    required this.startedAt,
    this.finishedAt,
    this.exercises = const [],
  });

  final WorkoutId id;
  final SessionId sessionId;
  final DateTime startedAt;

  /// Null medan passet pågår.
  final DateTime? finishedAt;
  final List<WorkoutExercise> exercises;

  bool get isFinished => finishedAt != null;

  /// Klart att avsluta när varje övning är gjord eller överhoppad.
  bool get canFinish =>
      exercises.isNotEmpty && exercises.every((e) => e.status != ExerciseStatus.open);
}
