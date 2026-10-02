import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';
import 'package:the_chain/mk1/mk1_codec.dart';
import 'package:the_chain/mk1/mk1_writer.dart';

Map<String, Object?> base() => {
      'appVersion': '3.95.0',
      'sessionOrder': ['A', 'B'],
      'restSlots': [2],
      'permanentSwaps': {'A2': 'Bench Press (BB)'},
      'exerciseNotes': {'ex_deadlift': 'belt'},
      'somethingNewerMk1Knows': {'keep': true},
      'log': <Object?>[],
      'cycles': [
        {
          'id': 1,
          'done': {'A': null, 'B': null, 'V': null},
        },
      ],
      'weightLog': [
        {'date': '2026-10-01', 'weight': 100.3, 'ts': 5},
      ],
    };

final start = DateTime(2026, 10, 2, 18), end = DateTime(2026, 10, 2, 19);
String nameOf(ExerciseId id) => libraryExercise(id)?.name ?? id.value;

WorkoutEntry workoutA() => WorkoutEntry(
      workout: Workout(
        id: const WorkoutId('w1'),
        sessionId: const SessionId('A'),
        startedAt: start,
        finishedAt: end,
        exercises: [
          const WorkoutExercise(
            id: 'r1',
            exerciseId: ExerciseId('ex_bench_press_bb'),
            measure: Measure.weight,
            slotId: SlotId('A1'),
            status: ExerciseStatus.done,
            sets: [
              SetEntry(id: SetId('s1'), kind: SetKind.warmup, values: SetValues(weight: 60, reps: 8), isLogged: true),
              SetEntry(
                  id: SetId('s2'),
                  kind: SetKind.work,
                  values: SetValues(weight: 112.5, reps: 3, forcedReps: 1),
                  target: SetValues(reps: 4),
                  isLogged: true),
              SetEntry(id: SetId('s3'), kind: SetKind.work), // ej loggat → skrivs inte
            ],
          ),
          const WorkoutExercise(
            id: 'r2',
            exerciseId: ExerciseId('ex_chins_supinated'), // tillfälligt byte på A2
            temporarySwapFrom: ExerciseId('ex_bench_press_bb'),
            measure: Measure.bodyweight,
            slotId: SlotId('A2'),
            status: ExerciseStatus.done,
            sets: [
              SetEntry(id: SetId('s4'), kind: SetKind.work, values: SetValues(extra: 10, reps: 6), isLogged: true, bodyweightKg: 100),
            ],
          ),
          const WorkoutExercise(
            id: 'r3',
            exerciseId: ExerciseId('ex_dead_hang'),
            measure: Measure.bodyweightTimed,
            status: ExerciseStatus.done,
            sets: [SetEntry(id: SetId('s5'), kind: SetKind.work, values: SetValues(secs: 70, extra: 0), isLogged: true)],
          ),
          const WorkoutExercise(
            id: 'r4',
            exerciseId: ExerciseId('ex_flyes_cable'),
            measure: Measure.weight,
            slotId: SlotId('A3'),
            status: ExerciseStatus.skipped,
          ),
        ],
      ),
    );

void main() {
  test('pass skrivs i MK1:s format och läses tillbaka identiskt', () {
    final out = appendWorkout(base(), workoutA(), nameOf: nameOf, sessionName: 'Chest + Tri');
    final back = decodeMk1(out).history.whereType<WorkoutEntry>().single.workout;
    expect(back.finishedAt, end);
    expect(back.startedAt, start);
    final bench = back.exercises.first;
    expect(bench.sets.length, 2); // ologgat set skrivs inte
    expect(bench.sets[1].values.weight, 112.5);
    expect(bench.sets[1].values.forcedReps, 1);
    expect(back.exercises[1].exerciseId, const ExerciseId('ex_chins_supinated'));
    expect(back.exercises[1].sets.single.bodyweightKg, 100);
    expect(back.exercises[2].isExtra, isTrue);
    expect(back.exercises[3].status, ExerciseStatus.skipped);
    // PR räknas lika på båda sidor (inget fail sätts av MK2)
    expect(personalRecords([workoutA()])[const ExerciseId('ex_bench_press_bb')]!.value,
        personalRecords(decodeMk1(out).history)[const ExerciseId('ex_bench_press_bb')]!.value);
  });

  test('passet markeras klart i hemsidans cykel och "förra gången" uppdateras', () {
    final out = appendWorkout(base(), workoutA(), nameOf: nameOf, sessionName: 'Chest + Tri');
    final cycles = out['cycles'] as List;
    expect(cycles.length, 1);
    final done = (cycles.last as Map)['done'] as Map;
    expect((done['A'] as Map)['date'], 'Fri 2 Oct');
    expect((out['lastSessionSetCount'] as Map)['ex_bench_press_bb'], 1);
    expect((out['lastSessionWarmupCount'] as Map)['ex_bench_press_bb'], 1);
  });

  test('full cykel → ny cykel startas först (som MK1:s doNewCycle)', () {
    final raw = base();
    raw['cycles'] = [
      {
        'id': 1,
        'done': {
          'A': {'timestamp': 1},
          'B': {'timestamp': 2},
          'V': {'timestamp': 3, 'rest': true},
        },
      },
    ];
    final out = appendWorkout(raw, workoutA(), nameOf: nameOf, sessionName: 'Chest + Tri');
    final cycles = out['cycles'] as List;
    expect(cycles.length, 2);
    final done = (cycles.last as Map)['done'] as Map;
    expect(done.keys, containsAll(['A', 'B', 'V']));
    expect(done['B'], isNull);
    expect(done['A'], isNotNull);
  });

  test('vilodag skrivs bara i cykeln, aldrig i log', () {
    final out = appendRest(base(), RestEntry(date: end, sessionId: const SessionId('V'), note: 'promenad'));
    expect((out['log'] as List), isEmpty);
    final done = ((out['cycles'] as List).last as Map)['done'] as Map;
    expect((done['V'] as Map)['rest'], isTrue);
    expect(decodeMk1(out).history.whereType<RestEntry>().single.sessionId, const SessionId('V'));
  });

  test('vikt: samma dag uppdateras med ny ts, ny dag läggs till', () {
    var out = upsertBodyweight(base(), const BodyweightEntry(date: '2026-10-01', kg: 99.8), end);
    var log = out['weightLog'] as List;
    expect(log.length, 1);
    expect((log.single as Map)['weight'], 99.8);
    expect((log.single as Map)['ts'], end.millisecondsSinceEpoch);
    out = upsertBodyweight(out, const BodyweightEntry(date: '2026-10-02', kg: 99.5), end);
    log = out['weightLog'] as List;
    expect(log.length, 2);
  });

  test('skyddade fält och okända fält rörs aldrig; originalet muteras inte', () {
    final raw = base();
    final before = jsonEncode(raw);
    var out = appendWorkout(raw, workoutA(), nameOf: nameOf, sessionName: 'Chest + Tri');
    out = appendRest(out, RestEntry(date: end, sessionId: const SessionId('V')));
    out = upsertBodyweight(out, const BodyweightEntry(date: '2026-10-02', kg: 99), end);
    for (final k in mk1ProtectedKeys) {
      expect(jsonEncode(out[k]), jsonEncode(raw[k]), reason: k);
    }
    expect(out['appVersion'], '3.95.0');
    expect(out['somethingNewerMk1Knows'], {'keep': true});
    expect(jsonEncode(raw), before);
  });

  test('pågående pass skrivs aldrig', () {
    final w = workoutA().workout;
    final running = WorkoutEntry(
        workout: Workout(id: w.id, sessionId: w.sessionId, startedAt: w.startedAt, exercises: w.exercises));
    expect(() => appendWorkout(base(), running, nameOf: nameOf, sessionName: 'x'), throwsArgumentError);
  });
}
