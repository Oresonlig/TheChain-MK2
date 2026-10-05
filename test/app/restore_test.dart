import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/data/backup.dart';
import 'package:the_chain/data/sync_engine.dart';
import 'package:the_chain/domain/domain.dart';

import 'fake_backend.dart';
import 'workout_controller_test.dart' show mk1;

Future<AppController> ready() async {
  var t = DateTime(2026, 10, 5, 18);
  final app = AppController(FakeBackend(mk1: mk1()), clock: () => t = t.add(const Duration(seconds: 1)));
  await app.start();
  await app.signIn('x', 'secret');
  await pumpEventQueue();
  await app.importFromWebsite();
  return app;
}

void main() {
  test('radera ett gammalt pass: borta ur historik och kedja; UNDO tar tillbaka det', () async {
    final app = await ready();
    final entry = app.repo!.history().whereType<WorkoutEntry>().single;
    final round = app.repo!.chain();
    await app.deleteHistoryEntry(entry);
    expect(app.repo!.history().whereType<WorkoutEntry>(), isEmpty);
    expect(app.repo!.chain().done, isNot(contains(entry.workout.sessionId)));
    expect(app.repo!.engine[Tables.workouts].items[entry.workout.id.value]!.isDeleted, isTrue, reason: 'tombstone');
    await app.restoreHistoryEntry(entry);
    expect(app.repo!.history().whereType<WorkoutEntry>().single.workout.id, entry.workout.id);
    expect(app.repo!.chain().done, round.done);
  });

  group('återställ från backup', () {
    test('lägger tillbaka det raderade; behåller det som ändrats efter; raderar inget', () async {
      final app = await ready();
      final backup = app.exportBackup('test');
      final w = app.repo!.history().whereType<WorkoutEntry>().single;
      final weight = app.repo!.bodyweight().single;
      // Efter backupen: passet raderas av misstag, vikten ändras, ett nytt pass loggas.
      await app.deleteHistoryEntry(w);
      await app.logBodyweight(99.9);
      final today = AppController.dayKey(DateTime(2026, 10, 5));
      final newer = WorkoutEntry(
        workout: Workout(id: const WorkoutId('after'), sessionId: const SessionId('A'), startedAt: DateTime(2026, 10, 5, 19), finishedAt: DateTime(2026, 10, 5, 20)),
      );
      await app.restoreHistoryEntry(newer);

      final plan = app.planBackupRestore(backup);
      expect(plan.count(Tables.workouts), 1, reason: 'det raderade passet');
      expect(plan.puts[Tables.workouts]!.keys.single, w.workout.id.value);
      await app.restore(plan);

      final ids = app.repo!.history().whereType<WorkoutEntry>().map((e) => e.workout.id.value).toSet();
      expect(ids, {w.workout.id.value, 'after'}, reason: 'tillbaka + det nya ligger kvar');
      expect(app.repo!.bodyweight().firstWhere((b) => b.date == weight.date).kg, weight.kg);
      expect(app.repo!.bodyweight().firstWhere((b) => b.date == today).kg, 99.9, reason: 'vägningen efter backupen');
      // En gång till: inget kvar att göra.
      expect(app.planBackupRestore(backup).isEmpty, isTrue);
    });

    test('fel fil → begripligt fel, inget skrivs', () async {
      final app = await ready();
      expect(() => app.planBackupRestore('not json'), throwsA(isA<BackupFormatError>()));
      expect(() => app.planBackupRestore('{"format":"other"}'), throwsA(isA<BackupFormatError>()));
    });
  });
}
