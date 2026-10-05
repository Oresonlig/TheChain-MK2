/// Ett pass som pågår eller är avslutat (Gör om #5). Synkas mellan enheter
/// även medan det pågår (beslut 2026-10-02).
library;

import 'ids.dart';
import 'measure.dart';
import 'set_entry.dart';

enum ExerciseStatus { open, done, skipped }

class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.exerciseId,
    required this.measure,
    this.slotId,
    this.temporarySwapFrom,
    this.status = ExerciseStatus.open,
    this.sets = const [],
  });

  /// Unikt inom passet. Samma övning kan förekomma två gånger (t.ex. som extra).
  final String id;

  /// Övningen som faktiskt körs.
  final ExerciseId exerciseId;

  /// Mätsättet när övningen lades i passet. Historik tolkas alltid i den form
  /// den loggades, även om användaren byter mätsätt senare (MK1 3.56.0).
  final Measure measure;

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

  /// DONE får tryckas när alla set är loggade och det finns minst ett.
  bool get canMarkDone => sets.isNotEmpty && sets.every((s) => s.isLogged);

  WorkoutExercise copyWith({
    ExerciseId? exerciseId,
    Measure? measure,
    ExerciseId? temporarySwapFrom,
    ExerciseStatus? status,
    List<SetEntry>? sets,
  }) =>
      WorkoutExercise(
        id: id,
        exerciseId: exerciseId ?? this.exerciseId,
        measure: measure ?? this.measure,
        slotId: slotId,
        temporarySwapFrom: temporarySwapFrom ?? this.temporarySwapFrom,
        status: status ?? this.status,
        sets: sets ?? this.sets,
      );
}

class Workout {
  const Workout({
    required this.id,
    required this.sessionId,
    required this.startedAt,
    this.sessionName,
    this.finishedAt,
    this.exercises = const [],
    this.note,
  });

  /// "How did it feel?" — frivillig anteckning vid avslut, går att ändra
  /// efteråt (Niklas 2026-10-05). Inga träningsdata: låset gäller inte den.
  final String? note;

  final WorkoutId id;
  final SessionId sessionId;

  /// Passets namn när det startades. "Lagt kort ligger": byter man namn på
  /// eller tar bort passet senare står historiken kvar som den var
  /// (Niklas 2026-10-04). Null = äldre post (fylls i en gång, se Repository).
  final String? sessionName;
  final DateTime startedAt;

  /// Null medan passet pågår.
  final DateTime? finishedAt;
  final List<WorkoutExercise> exercises;

  bool get isFinished => finishedAt != null;

  Workout copyWith({DateTime? finishedAt, List<WorkoutExercise>? exercises, String? sessionName}) => Workout(
        id: id,
        sessionId: sessionId,
        sessionName: sessionName ?? this.sessionName,
        startedAt: startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        exercises: exercises ?? this.exercises,
        note: note,
      );

  /// Tom eller bara blanksteg = ingen anteckning.
  Workout withNote(String? text) {
    final t = text?.trim();
    return Workout(
      id: id,
      sessionId: sessionId,
      sessionName: sessionName,
      startedAt: startedAt,
      finishedAt: finishedAt,
      exercises: exercises,
      note: (t == null || t.isEmpty) ? null : t,
    );
  }

  /// Klart att avsluta när varje övning är gjord eller överhoppad.
  bool get canFinish =>
      exercises.isNotEmpty && exercises.every((e) => e.status != ExerciseStatus.open);
}
