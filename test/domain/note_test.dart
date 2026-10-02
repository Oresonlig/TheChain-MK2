import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';

const bench = ExerciseId('bench'), row = ExerciseId('row');
final t0 = DateTime(2026, 10, 1, 18), start = DateTime(2026, 10, 3, 18), end = DateTime(2026, 10, 3, 19);

ExerciseNote note(String id, ExerciseId ex, {DateTime? at, bool pinned = false}) =>
    ExerciseNote(id: id, exerciseId: ex, text: id, createdAt: at ?? t0, pinned: pinned);

Workout workout(Map<ExerciseId, ExerciseStatus> exs, {DateTime? finished}) => Workout(
      id: const WorkoutId('w1'),
      sessionId: const SessionId('A'),
      startedAt: start,
      finishedAt: finished ?? end,
      exercises: [
        for (final e in exs.entries)
          WorkoutExercise(id: e.key.value, exerciseId: e.key, measure: Measure.weight, status: e.value),
      ],
    );

void main() {
  test('"till nästa pass" arkiveras när övningen gjorts', () {
    final out = archiveAfterWorkout([note('höj 2,5', bench)], workout({bench: ExerciseStatus.done}));
    expect(out.single.isActive, isFalse);
    expect(out.single.archivedIn, const WorkoutId('w1'));
    expect(out.single.archivedAt, end);
  });

  test('nålad anteckning ligger kvar', () {
    final out = archiveAfterWorkout([note('sits 4', bench, pinned: true)], workout({bench: ExerciseStatus.done}));
    expect(out.single.isActive, isTrue);
  });

  test('anteckning skriven UNDER passet visas nästa gång', () {
    final during = DateTime(2026, 10, 3, 18, 30);
    final out = archiveAfterWorkout([note('ny', bench, at: during)], workout({bench: ExerciseStatus.done}));
    expect(out.single.isActive, isTrue);
  });

  test('överhoppad eller ej körd övning arkiverar ingenting', () {
    final out = archiveAfterWorkout(
      [note('b', bench), note('r', row)],
      workout({bench: ExerciseStatus.skipped}),
    );
    expect(out.every((n) => n.isActive), isTrue);
  });

  test('pågående pass arkiverar ingenting', () {
    final w = Workout(
      id: const WorkoutId('w2'),
      sessionId: const SessionId('A'),
      startedAt: start,
      exercises: const [
        WorkoutExercise(id: 'r', exerciseId: bench, measure: Measure.weight, status: ExerciseStatus.done),
      ],
    );
    expect(archiveAfterWorkout([note('b', bench)], w).single.isActive, isTrue);
  });

  test('activeNotes visar bara aktiva för rätt övning', () {
    final notes = [note('a', bench), note('b', row), note('c', bench).archive(end, const WorkoutId('w0'))];
    expect(activeNotes(notes, bench).map((n) => n.id), ['a']);
  });
}
