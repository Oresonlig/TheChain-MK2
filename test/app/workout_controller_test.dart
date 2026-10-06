import 'dart:async';

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
  test('FINISH väntar aldrig på nätet; avslutat pass kan inte avslutas igen (Niklas 2026-10-06)', () async {
    final app = await ready();
    final open = app.openWorkout(const SessionId('A'));
    final hang = Completer<void>(); // synk som aldrig blir klar (dåligt gym-nät)
    final wc = WorkoutController(repo: app.repo!, workout: open.workout, newId: app.newId, onFinished: () => hang.future);
    for (final r in wc.workout.exercises) {
      logAll(wc, r);
      wc.markDone(r.id);
    }
    expect(wc.canFinish, isTrue);
    expect(await wc.finish(note: 'first').timeout(const Duration(seconds: 2)), isTrue);
    expect(app.repo!.activeWorkouts(), isEmpty, reason: 'sparat lokalt innan synken');
    expect(wc.canFinish, isFalse, reason: 'FINISH släckt efter avslut');
  });

  test('anteckning vid avslut: sparas, ändras, tas bort; UNDO behåller den', () async {
    final app = await ready();
    final wc = app.openWorkout(const SessionId('A'));
    for (final r in wc.workout.exercises) {
      logAll(wc, r);
      wc.markDone(r.id);
    }
    expect(await wc.finish(note: '  Slept 4 h  '), isTrue);
    WorkoutEntry last() => app.repo!.history().whereType<WorkoutEntry>().firstWhere((e) => e.workout.id == wc.workout.id);
    expect(last().workout.note, 'Slept 4 h');
    final sets = last().workout.exercises.expand((x) => x.sets).length;
    await app.setWorkoutNote(last(), 'Felt strong');
    expect(last().workout.note, 'Felt strong');
    expect(last().workout.exercises.expand((x) => x.sets).length, sets, reason: 'seten rörs inte');
    await app.undoWorkout(last());
    expect(app.repo!.activeWorkouts().single.note, 'Felt strong');
    final wc2 = app.openWorkout(const SessionId('A'));
    await wc2.finish();
    await app.setWorkoutNote(last(), '   ');
    expect(last().workout.note, isNull);
  });

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
    await pumpEventQueue(); // synken går i bakgrunden efter FINISH
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

  test('ta bort övning ur programmet permanent: utan loggat försvinner raden, med loggat blir den extra', () async {
    final app = await ready();
    final wc = app.openWorkout(const SessionId('A'));
    final first = wc.workout.exercises[0], second = wc.workout.exercises[1];

    await wc.removeFromProgram(first.id);
    expect(wc.error, isNull);
    expect(wc.workout.exercises.any((r) => r.id == first.id), isFalse);
    expect(app.repo!.program().sessionById(const SessionId('A'))!.slots.any((s) => s.id == first.slotId), isFalse);
    expect(wc.expandedRowId, second.id); // nästa öppna expanderas

    wc.setValues(second.id, second.sets.first.id, const SetValues(weight: 50, reps: 8));
    wc.toggleLog(second.id, second.sets.first.id);
    await wc.removeFromProgram(second.id);
    final kept = wc.workout.exercises.firstWhere((r) => r.id == second.id);
    expect(kept.isExtra, isTrue);
    expect(kept.sets.first.isLogged, isTrue); // inget loggat försvinner
    expect(app.repo!.program().sessionById(const SessionId('A'))!.slots.length, 2);

    // Nästa gång passet startas finns övningarna inte med.
    expect(app.repo!.activeWorkoutFor(const SessionId('A'))!.exercises.length, 3);
  });

  test('ett pass i taget: nytt pass medan ett annat pågår nekas; samma pass återupptas', () async {
    final app = await ready();
    final a = app.openWorkout(const SessionId('A'));
    expect(() => app.openWorkout(const SessionId('B')), throwsA(isA<WorkoutError>()));
    expect(app.openWorkout(const SessionId('A')).workout.id, a.workout.id);
    expect(app.repo!.activeWorkouts().length, 1);
  });

  test('vikt: radera + UNDO ger tillbaka samma dag och vikt', () async {
    final app = await ready();
    final e = app.repo!.bodyweight().single;
    await app.deleteBodyweight(e.date);
    expect(app.repo!.bodyweight(), isEmpty);
    await app.restoreBodyweight(e);
    expect(app.repo!.bodyweight().single.kg, e.kg);
    expect(app.repo!.bodyweight().single.date, e.date);
  });

  test('hoppa över pass med anledning + UNDO (synkas som egen post)', () async {
    final app = await ready();
    await app.skipSession(const SessionId('A'), 'New tattoo');
    final st = app.repo!.chain();
    expect(st.isSkipped(const SessionId('A')), isTrue);
    expect(st.isDone(const SessionId('A')), isFalse);
    final entry = app.repo!.history().whereType<SkippedEntry>().single;
    expect(entry.reason, 'New tattoo');
    await app.undoSkip(entry);
    expect(app.repo!.chain().isSkipped(const SessionId('A')), isFalse);
    expect(app.repo!.history().whereType<SkippedEntry>(), isEmpty);
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
