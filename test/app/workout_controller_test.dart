import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/app/workout_controller.dart';
import 'package:the_chain/domain/domain.dart';

import 'fake_backend.dart';

final t0 = DateTime(2026, 9, 20, 18).millisecondsSinceEpoch;

Map<String, Object?> mk1() => {
      'sessionOrder': ['A', 'B'],
      'restSlots': [2],
      'weightLog': [
        {'date': '2026-09-20', 'weight': 100.0},
      ],
      'log': [
        {
          'passId': 'B',
          'timestamp': t0,
          'exercises': [
            {
              'id': 'B2',
              'name': 'Deadlift',
              'exId': 'ex_deadlift',
              'measure': 'weight',
              'sets': [
                {'warmup': false, 'weight': 180, 'reps': 3},
                {'warmup': false, 'weight': 190, 'reps': 2},
              ],
            },
          ],
        },
      ],
      'cycles': [
        {'id': 1, 'done': {'B': {'timestamp': t0}}},
      ],
    };

/// Loggar varje set på raden (DONE kräver det sedan 2026-10-03).
void logAll(WorkoutController wc, WorkoutExercise r) {
  for (final s in r.sets) {
    wc.setValues(r.id, s.id, const SetValues(weight: 50, reps: 8, secs: 60));
    wc.toggleLog(r.id, s.id);
  }
}

Future<AppController> ready() async {
  var t = DateTime(2026, 10, 2, 18);
  final app = AppController(FakeBackend(mk1: mk1()), clock: () => t = t.add(const Duration(seconds: 1)));
  await app.start();
  await app.signIn('x', 'secret');
  await pumpEventQueue();
  await app.importFromWebsite();
  return app;
}

void main() {
  test('starta → logga → klar → avsluta: historik, kedja och synk', () async {
    final app = await ready();
    expect(app.repo!.chain().next, const SessionId('A'));
    final wc = app.openWorkout(const SessionId('A'));
    expect(wc.workout.exercises.length, 4);
    expect(wc.expandedRowId, wc.workout.exercises.first.id);
    for (final r in wc.workout.exercises) {
      wc.markDone(r.id);
      expect(wc.error, isNotNull); // inget loggat → DONE nekas
      wc.takeError();
      logAll(wc, r);
      wc.markDone(r.id);
      expect(wc.error, isNull);
    }
    expect(wc.canFinish, isTrue);
    expect(await wc.finish(), isTrue);
    final repo = app.repo!;
    expect(repo.activeWorkouts(), isEmpty);
    expect(repo.history().whereType<WorkoutEntry>().length, 2);
    expect(repo.chain().done, containsAll([const SessionId('A'), const SessionId('B')]));
    expect(repo.chain().next, const SessionId('V'));
    expect(app.status, 'Synced');
  });

  test('pågående pass återupptas efter omstart och räknas inte som historik', () async {
    final app = await ready();
    final wc = app.openWorkout(const SessionId('A'));
    final r = wc.workout.exercises.first;
    wc.setValues(r.id, r.sets.last.id, const SetValues(weight: 100, reps: 5));
    wc.toggleLog(r.id, r.sets.last.id);
    expect(app.repo!.history().length, 1); // bara MK1-passet
    final again = app.openWorkout(const SessionId('A')); // "appen startades om"
    expect(again.workout.id, wc.workout.id);
    expect(again.workout.exercises.first.sets.last.isLogged, isTrue);
  });

  test('standardset följer förra passet; ramp utan uppvärmning', () async {
    final app = await ready();
    await app.repo!.saveOverride(const ExerciseId('ex_deadlift'), const ExerciseOverride(scheme: SetScheme.ramp), DateTime(2026, 10, 2));
    final wc = app.openWorkout(const SessionId('B'));
    final dl = wc.workout.exercises.firstWhere((r) => r.exerciseId == const ExerciseId('ex_deadlift'));
    expect(dl.sets.where((s) => s.kind == SetKind.warmup), isEmpty);
    expect(dl.sets.where((s) => s.kind == SetKind.work).length, 2);
  });

  test('kroppsvikt fångas på BW-övningar vid loggning', () async {
    final app = await ready();
    final wc = app.openWorkout(const SessionId('B'));
    final hang = wc.workout.exercises.firstWhere((r) => r.exerciseId == const ExerciseId('ex_dead_hang'));
    final s = hang.sets.first;
    wc.setValues(hang.id, s.id, const SetValues(extra: 5, secs: 60));
    wc.toggleLog(hang.id, s.id);
    expect(wc.workout.exercises.firstWhere((r) => r.id == hang.id).sets.first.bodyweightKg, 100.0);
  });

  test('anteckning "till nästa pass" arkiveras vid avslut; skriven under passet ligger kvar', () async {
    final app = await ready();
    final bench = const ExerciseId('ex_bench_press_bb');
    final wc0 = app.openWorkout(const SessionId('A'));
    await wc0.addNote(bench, 'raise 2.5 kg');
    await wc0.discard();
    final wc = app.openWorkout(const SessionId('A'));
    await wc.addNote(bench, 'seat 4', pinned: true);
    for (final r in wc.workout.exercises) {
      logAll(wc, r);
      wc.markDone(r.id);
    }
    await wc.finish();
    final active = activeNotes(app.repo!.notes(), bench).map((n) => n.text).toSet();
    expect(active, {'seat 4'});
  });

  test('UNDO: avslutat pass öppnas igen med allt loggat; nytt avslut ger INGEN dubblett', () async {
    final app = await ready();
    final wc = app.openWorkout(const SessionId('A'));
    final r = wc.workout.exercises.first;
    wc.setValues(r.id, r.sets.last.id, const SetValues(weight: 100, reps: 5));
    wc.toggleLog(r.id, r.sets.last.id);
    for (final x in wc.workout.exercises) {
      if (x.id == r.id) {
        for (final s in x.sets.where((s) => !s.isLogged && s.id != r.sets.last.id)) {
          wc.removeSet(r.id, s.id);
        }
        wc.markDone(x.id);
      } else {
        wc.skip(x.id);
      }
    }
    await wc.finish();
    final repo = app.repo!;
    expect(repo.chain().isDone(const SessionId('A')), isTrue);
    final entry = repo.history().whereType<WorkoutEntry>().firstWhere((e) => e.workout.sessionId == const SessionId('A'));

    await app.undoWorkout(entry);
    expect(repo.chain().isDone(const SessionId('A')), isFalse);
    expect(repo.history().whereType<WorkoutEntry>().length, 1); // bara MK1-passet
    final again = app.openWorkout(const SessionId('A'));
    expect(again.workout.id, entry.workout.id);
    expect(again.workout.exercises.first.sets.last.values.weight, 100);

    await again.finish();
    expect(repo.history().whereType<WorkoutEntry>().length, 2);
    expect(repo.chain().isDone(const SessionId('A')), isTrue);
  });

  test('UNDO av vilodag', () async {
    final app = await ready();
    await app.markRestDone(const SessionId('V'));
    expect(app.repo!.chain().isDone(const SessionId('V')), isTrue);
    await app.undoRest(app.repo!.history().whereType<RestEntry>().single);
    expect(app.repo!.chain().isDone(const SessionId('V')), isFalse);
  });

  test('vikt: en per dag (samma dag skrivs över), radering; inställningar sparas', () async {
    final app = await ready();
    await app.logBodyweight(99.5);
    await app.logBodyweight(99.2);
    final today = app.repo!.bodyweight().where((e) => e.date == AppController.dayKey(DateTime(2026, 10, 2))).toList();
    expect(today.single.kg, 99.2);
    await app.deleteBodyweight(today.single.date);
    expect(app.repo!.bodyweight().where((e) => e.date == today.single.date), isEmpty);
    await app.updateSettings(const UserSettings(weightUnit: WeightUnit.lbs, ambientEffects: false));
    expect(app.repo!.settings().weightUnit, WeightUnit.lbs);
    expect(app.repo!.settings().ambientEffects, isFalse);
  });

  test('vilodag markeras klar med anteckning', () async {
    final app = await ready();
    await app.markRestDone(const SessionId('V'), note: 'walk');
    final rest = app.repo!.history().whereType<RestEntry>().single;
    expect(rest.note, 'walk');
  });

  test('fel visas i stället för krasch (ta bort loggat set)', () async {
    final app = await ready();
    final wc = app.openWorkout(const SessionId('A'));
    final r = wc.workout.exercises.first;
    wc.toggleLog(r.id, r.sets.first.id);
    wc.removeSet(r.id, r.sets.first.id);
    expect(wc.error, 'Unlog the set before removing it');
  });
}
