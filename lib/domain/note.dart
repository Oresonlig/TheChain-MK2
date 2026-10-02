/// Anteckningar per övning (beslut 2026-10-02). Standard = "till nästa pass":
/// visas i nästa pass där övningen görs och arkiveras sedan i historiken.
/// Nålad = ligger kvar tills användaren tar bort den ("sitsen på 4").
/// MK1:s anteckningar försvann aldrig — det var inte avsikten.
library;

import 'ids.dart';
import 'workout.dart';

class ExerciseNote {
  const ExerciseNote({
    required this.id,
    required this.exerciseId,
    required this.text,
    required this.createdAt,
    this.pinned = false,
    this.archivedAt,
    this.archivedIn,
  });

  final String id;
  final ExerciseId exerciseId;
  final String text;
  final DateTime createdAt;
  final bool pinned;

  /// Satt när anteckningen har visats i ett avslutat pass och flyttats till historiken.
  final DateTime? archivedAt;
  final WorkoutId? archivedIn;

  bool get isActive => archivedAt == null;

  ExerciseNote archive(DateTime at, WorkoutId inWorkout) => ExerciseNote(
        id: id,
        exerciseId: exerciseId,
        text: text,
        createdAt: createdAt,
        pinned: pinned,
        archivedAt: at,
        archivedIn: inWorkout,
      );
}

/// Aktiva anteckningar som visas för en övning.
Iterable<ExerciseNote> activeNotes(Iterable<ExerciseNote> notes, ExerciseId id) =>
    notes.where((n) => n.isActive && n.exerciseId == id);

/// Körs när ett pass avslutas. Ej nålade anteckningar för övningar som GJORDES
/// i passet arkiveras — men bara de som fanns innan passet startade, så att en
/// anteckning skriven under passet ("höj 2,5 kg") visas nästa gång.
/// Överhoppade övningar arkiverar ingenting.
List<ExerciseNote> archiveAfterWorkout(Iterable<ExerciseNote> notes, Workout w) {
  final finishedAt = w.finishedAt;
  if (finishedAt == null) return notes.toList();
  final done = {
    for (final e in w.exercises)
      if (e.status == ExerciseStatus.done) e.exerciseId,
  };
  return [
    for (final n in notes)
      if (n.isActive && !n.pinned && done.contains(n.exerciseId) && n.createdAt.isBefore(w.startedAt))
        n.archive(finishedAt, w.id)
      else
        n,
  ];
}
