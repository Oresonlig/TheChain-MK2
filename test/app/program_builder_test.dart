// Programbyggaren (Niklas 2026-10-04): sparas direkt med UNDO, pågående pass
// är en ögonblicksbild, historiken behåller passnamnet, egna övningar raderas
// aldrig och ett bytt mätsätt startar om rekordet.
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/domain/domain.dart';

import 'fake_backend.dart';
import 'workout_controller_test.dart' show logAll, mk1;

Future<AppController> ready() async {
  var t = DateTime(2026, 10, 4, 18);
  final app = AppController(FakeBackend(mk1: mk1()), clock: () => t = t.add(const Duration(seconds: 1)));
  await app.start();
  await app.signIn('x', 'secret');
  await pumpEventQueue();
  await app.importFromWebsite();
  return app;
}

const a = SessionId('A'), b = SessionId('B');

void main() {
  test('ändringar sparas direkt; UNDO lägger tillbaka programmet', () async {
    final app = await ready();
    final repo = app.repo!;
    final original = repo.program();
    final slot = original.sessionById(a)!.slots.first;

    final before = await app.editProgram((p) => removeSlot(p, a, slot.id));
    expect(repo.program().sessionById(a)!.slots.any((s) => s.id == slot.id), isFalse);
    await app.restoreProgram(before);
    expect(repo.program().sessionById(a)!.slots.map((s) => s.id), original.sessionById(a)!.slots.map((s) => s.id));

    // Nekad ändring: inget sparas.
    await expectLater(() => app.editProgram((p) => renameSession(p, a, ' ')), throwsA(isA<WorkoutError>()));
    expect(repo.program().sessionById(a)!.name, original.sessionById(a)!.name);
    app.dispose();
  });

  test('pågående pass påverkas inte; kan inte tas bort förrän det är klart', () async {
    final app = await ready();
    final repo = app.repo!;
    final wc = app.openWorkout(a);
    final rows = wc.workout.exercises.length;
    final name = repo.program().sessionById(a)!.name;

    await app.editProgram((p) => removeSlot(p, a, p.sessionById(a)!.slots.first.id));
    expect(repo.activeWorkoutFor(a)!.exercises.length, rows);
    await expectLater(() => app.deleteSession(a), throwsA(isA<WorkoutError>()));

    for (final r in wc.workout.exercises) {
      logAll(wc, r);
      wc.markDone(r.id);
    }
    expect(await wc.finish(), isTrue);

    // Omdöpt och sedan borttaget: historiken heter som när passet kördes.
    await app.editProgram((p) => renameSession(p, a, 'Push'));
    await app.deleteSession(a);
    final entry = repo.history().whereType<WorkoutEntry>().firstWhere((e) => e.workout.sessionId == a);
    expect(repo.sessionNameOf(entry), name);
    expect(repo.program().sessionById(a), isNull);
    app.dispose();
  });

  test('egna övningar: krock med biblioteket, borttagning arkiverar, återuppstår', () async {
    final app = await ready();
    final repo = app.repo!;
    const draft = Exercise(id: ExerciseId('new'), name: 'Bench Press (BB)', group: MuscleGroup.chest, measure: Measure.weight);
    await expectLater(() => app.createExercise(draft), throwsA(isA<WorkoutError>()));

    final mine = await app.createExercise(const Exercise(
        id: ExerciseId('new'), name: ' Cable Fly ', group: MuscleGroup.chest, measure: Measure.weight, scheme: SetScheme.ramp));
    expect(mine.name, 'Cable Fly');
    expect(repo.exercise(mine.id)!.scheme, SetScheme.ramp);
    await expectLater(() => app.createExercise(mine), throwsA(isA<WorkoutError>()));

    await app.editProgram((p) => addSlot(p, b, Slot(id: const SlotId('x1'), exerciseId: mine.id)));
    await expectLater(() => app.archiveExercise(mine.id), throwsA(isA<WorkoutError>()));
    await app.editProgram((p) => removeSlot(p, b, const SlotId('x1')));
    await app.archiveExercise(mine.id);
    expect(repo.exercise(mine.id)!.archived, isTrue);
    expect(repo.exercise(mine.id)!.name, 'Cable Fly'); // historiken behåller namnet

    final back = await app.createExercise(mine.copyWith(measure: Measure.repsOnly));
    expect(repo.exercise(back.id)!.archived, isFalse);
    expect(repo.exercise(back.id)!.measure, Measure.repsOnly);
    app.dispose();
  });

  test('biblioteksövning: bara det som skiljer sparas; nytt mätsätt startar om PR', () async {
    final app = await ready();
    final repo = app.repo!;
    const dead = ExerciseId('ex_deadlift');
    expect(repo.records()[dead]!.value, 190);

    await app.saveExercise(repo.exercise(dead)!.copyWith(measure: Measure.repsOnly));
    expect(repo.overrides()[dead]!.measure, Measure.repsOnly);
    expect(repo.records()[dead], isNull);

    await app.saveExercise(repo.exercise(dead)!.copyWith(measure: libraryExercise(dead)!.measure));
    expect(repo.overrides()[dead]!.measure, isNull);
    expect(repo.records()[dead]!.value, 190);
    app.dispose();
  });
}
