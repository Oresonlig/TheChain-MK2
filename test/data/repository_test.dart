import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/data/file_store.dart';
import 'package:the_chain/data/repository.dart';
import 'package:the_chain/data/sync_engine.dart';
import 'package:the_chain/domain/domain.dart';
import 'package:the_chain/mk1/mk1_codec.dart';

import 'fake_remote.dart';

final t1 = DateTime(2026, 9, 20, 18).millisecondsSinceEpoch;
final t2 = DateTime(2026, 9, 22, 18).millisecondsSinceEpoch;
final now = DateTime(2026, 10, 2, 12);

Map<String, Object?> mk1() => {
      'sessionOrder': ['A', 'B'],
      'restSlots': [2],
      'permanentSwaps': {'A2': 'Bench Press (BB)'},
      'exerciseNotes': {'ex_deadlift': 'belt'},
      'exerciseTagOverrides': {'ex_deadlift': {'ramp': false}},
      'customExercises': [
        {'id': 'custom_1', 'name': 'My Hold', 'timed': true, 'cat': 'Core'},
      ],
      'ignoredPRs': ['Lat Prayers'],
      'weightLog': [
        {'date': '2026-09-20', 'weight': 100.3, 'ts': t1},
      ],
      'timerDefault': 90,
      'log': [
        {
          'passId': 'A',
          'timestamp': t1,
          'exercises': [
            {
              'id': 'A1',
              'name': 'Bench Press (BB)',
              'exId': 'ex_bench_press_bb',
              'measure': 'weight',
              'sets': [
                {'warmup': false, 'weight': 110, 'reps': 4},
              ],
            },
          ],
        },
      ],
      'cycles': [
        {
          'id': t1 - 1000,
          'done': {
            'A': {'timestamp': t1},
            'V': {'timestamp': t2, 'rest': true},
          },
        },
      ],
    };

Future<Repository> device(FakeRemote server, String id, [LocalStore? store]) async {
  final e = SyncEngine(remote: server, store: store ?? InMemoryLocalStore(), deviceId: id);
  await e.open();
  return Repository(e);
}

void main() {
  test('importen ger samma historik, PR, program, vikt och inställningar', () async {
    final snap = decodeMk1(mk1());
    final repo = await device(FakeRemote(), 'phone');
    await repo.importMk1(snap, now);
    expect(repo.history().length, snap.history.length);
    expect(personalRecords(repo.history())[const ExerciseId('ex_bench_press_bb')]!.value, 110);
    expect(repo.program().sessions.map((s) => s.id.value), ['A', 'B', 'V']);
    expect(repo.program().sessions.first.slots[1].originalExerciseId, const ExerciseId('ex_incline_press_smith'));
    expect(repo.bodyweight().single.kg, 100.3);
    expect(repo.notes().single.pinned, isTrue);
    expect(repo.customExercises().keys, [const ExerciseId('custom_1')]);
    expect(repo.overrides()[const ExerciseId('ex_deadlift')]!.scheme, SetScheme.standard);
    expect(repo.exercise(const ExerciseId('ex_deadlift'))!.scheme, SetScheme.standard);
    expect(repo.settings().restTimerSecs, 90);
    expect(repo.hiddenRecords(), {const ExerciseId('ex_lat_prayers')});
    expect(repo.chain().round, snap.mk1Round);
  });

  test('importerat på telefonen syns på en annan enhet efter synk', () async {
    final server = FakeRemote();
    final phone = await device(server, 'phone');
    await phone.importMk1(decodeMk1(mk1()), now);
    await phone.engine.syncAll();
    final tablet = await device(server, 'tablet');
    await tablet.engine.syncAll();
    expect(tablet.history().length, phone.history().length);
    expect(tablet.program().sessions.length, 3);
    expect(tablet.chain().round, phone.chain().round);
  });

  test('ett nytt pass sparas, synkas och ändrar kedjan', () async {
    final server = FakeRemote();
    final repo = await device(server, 'phone');
    await repo.importMk1(decodeMk1(mk1()), now);
    final before = repo.chain();
    final w = Workout(
      id: const WorkoutId('w-new'),
      sessionId: const SessionId('B'),
      startedAt: now,
      finishedAt: now.add(const Duration(hours: 1)),
    );
    await repo.saveHistory(WorkoutEntry(workout: w), now);
    await repo.engine.syncAll();
    expect(server.table(Tables.workouts).containsKey('w-new'), isTrue);
    // A och vilodagen var redan gjorda — B fullbordar cykeln.
    expect(before.done, {const SessionId('A'), const SessionId('V')});
    expect(repo.chain().round, before.round + 1);
    expect(repo.chain().done, isEmpty);
  });

  test('fillagringen överlever omstart (riktiga filer)', () async {
    final dir = Directory('build/test_tmp/file_store');
    if (await dir.exists()) await dir.delete(recursive: true);
    final server = FakeRemote()..offline = true;
    final a = await device(server, 'phone', FileLocalStore(dir));
    await a.saveBodyweight(const BodyweightEntry(date: '2026-10-02', kg: 99.8), now);
    await a.saveNote(ExerciseNote(id: 'n', exerciseId: const ExerciseId('x'), text: 'hi', createdAt: now), now);
    final b = await device(server, 'phone', FileLocalStore(dir));
    expect(b.bodyweight().single.kg, 99.8);
    expect(b.notes().single.text, 'hi');
    expect(b.engine[Tables.bodyweight].pendingCount, 1);
    await dir.delete(recursive: true);
  });
}
