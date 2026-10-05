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
  test('passnamnet fylls i EN gång; omdöpt eller borttaget pass ändrar inte historiken', () async {
    final repo = await device(FakeRemote(), 'phone');
    const a = SessionId('A');
    await repo.saveProgram(const Program(sessions: [Session(id: a, name: 'Chest'), Session(id: SessionId('B'), name: 'Back')]), now);
    final old = Workout(
      id: const WorkoutId('w1'),
      sessionId: a,
      startedAt: now,
      finishedAt: now.add(const Duration(hours: 1)),
    );
    await repo.saveHistory(WorkoutEntry(workout: old), now);
    await repo.saveHistory(SkippedEntry(date: now, sessionId: const SessionId('B'), reason: 'sick'), now);
    // Pågående pass rörs inte (passvyn har egen kopia).
    await repo.saveActiveWorkout(Workout(id: const WorkoutId('w2'), sessionId: a, startedAt: now), now);

    expect(await repo.backfillSessionNames(now), 2);
    expect(await repo.backfillSessionNames(now), 0);
    expect(repo.activeWorkouts().single.sessionName, isNull);

    await repo.saveProgram(const Program(sessions: [Session(id: a, name: 'Push')]), now);
    expect(await repo.backfillSessionNames(now), 0);
    final names = {for (final h in repo.history()) Repository.historyId(h): repo.sessionNameOf(h)};
    expect(names, {'w1': 'Chest', 'skip.B.${now.millisecondsSinceEpoch}': 'Back'});
    // Ett pass utan sparat namn vars pass är borttaget: neutralt namn, aldrig ett id.
    expect(repo.sessionNameOf(WorkoutEntry(workout: Workout(id: const WorkoutId('x'), sessionId: const SessionId('zz'), startedAt: now))),
        'Session');
  });

  test('importen ger samma historik, PR, program, vikt och inställningar', () async {
    final snap = decodeMk1(mk1());
    final repo = await device(FakeRemote(), 'phone');
    await repo.importMk1(snap, now);
    expect(repo.history().length, snap.history.length);
    expect(personalRecords(repo.history())[const ExerciseId('ex_bench_press_bb')]!.value, 110);
    expect(repo.program().sessions.map((s) => s.id.value), ['A', 'B', 'V']);
    expect(repo.bodyweight().single.kg, 100.3);
    expect(repo.notes().single.pinned, isTrue);
    expect(repo.customExercises().keys, [const ExerciseId('custom_1')]);
    expect(repo.overrides()[const ExerciseId('ex_deadlift')]!.scheme, SetScheme.standard);
    expect(repo.exercise(const ExerciseId('ex_deadlift'))!.scheme, SetScheme.standard);
    expect(repo.settings().restTimerSecs, 90);
    expect(repo.chain().round, snap.mk1Round);
  });

  test('import med eget program: KEEP behåller programmet, historiken kommer in; appens egna val ligger kvar', () async {
    final repo = await device(FakeRemote(), 'phone');
    const mine = Program(sessions: [Session(id: SessionId('X'), name: 'My push day')]);
    await repo.saveProgram(mine, now);
    await repo.saveSettings(const UserSettings(workoutTourSeen: true, finishNote: false), now);
    final snap = decodeMk1(mk1());

    await repo.importMk1(snap, now, keepProgram: true);
    expect(repo.program().sessions.single.name, 'My push day', reason: 'det nybyggda schemat försvinner inte');
    expect(repo.history().length, snap.history.length);
    final s = repo.settings();
    expect(s.importedFromWebsite, isTrue);
    expect(s.workoutTourSeen, isTrue, reason: 'appens egna val skrivs inte över');
    expect(s.finishNote, isFalse);
    expect(s.restTimerSecs, 90, reason: 'hemsidans vilotimer följer med');

    await repo.importMk1(snap, now);
    expect(repo.program().sessions.map((x) => x.id.value), ['A', 'B', 'V'], reason: "\"Use the website's\"");
  });

  test('inga dolda PR — även en äldre synkad "hiddenRecords"-lista ignoreras', () async {
    final repo = await device(FakeRemote(), 'phone');
    await repo.importMk1(decodeMk1(mk1()), now);
    const bench = ExerciseId('ex_bench_press_bb');
    // Som Niklas data efter importen 2026-10-02: bänken stod på listan.
    await repo.engine[Tables.settings].put('settings', {'v': 1, 'hiddenRecords': [bench.value]}, now);
    expect(repo.records()[bench]!.value, 110);
    await repo.saveSettings(repo.settings(), now);
    expect(repo.engine[Tables.settings].items['settings']!.value!.containsKey('hiddenRecords'), isFalse,
        reason: 'nästa sparning tar bort resten ur datan');
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

  test('en trasig post i historiken tar inte ner resten (kedja, PR, historik)', () async {
    final repo = await device(FakeRemote(), 'phone');
    await repo.importMk1(decodeMk1(mk1()), now);
    final before = repo.history().length;
    await repo.engine[Tables.workouts].put('broken', {'type': 'workout', 'workout': {'id': 42}}, now);
    expect(repo.history().length, before);
    expect(repo.chain().round, greaterThan(0));
  });

  test('vilodag och överhopp behåller sin källa (importerat) genom lagringen', () async {
    final repo = await device(FakeRemote(), 'phone');
    const b = SessionId('B');
    await repo.saveHistory(RestEntry(date: now, sessionId: b, source: EntrySource.imported), now);
    await repo.saveHistory(SkippedEntry(date: now, sessionId: b, reason: 'sick', source: EntrySource.imported), now);
    expect(repo.history().map((h) => h.source).toSet(), {EntrySource.imported});
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
