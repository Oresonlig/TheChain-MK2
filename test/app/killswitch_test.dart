// Killswitch + säkerhetskopia (Niklas 2026-10-03): efter flytten får import
// aldrig kunna skriva över appens data med hemsidans gamla.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/data/backup.dart';
import 'package:the_chain/data/sync_engine.dart';

import 'app_flow_test.dart' show mk1;
import 'fake_backend.dart';

Future<(AppController, FakeBackend)> signedIn({DateTime? movedAt, bool offline = false}) async {
  final b = FakeBackend(mk1: mk1())
    ..movedAt = movedAt
    ..migrationOffline = offline;
  final app = AppController(b, syncDelay: const Duration(milliseconds: 1));
  await app.start();
  await app.signIn('x', 'secret');
  await pumpEventQueue();
  return (app, b);
}

void main() {
  test('ej flyttat: import fungerar, flytt sätter markeringen och stänger import', () async {
    final (app, b) = await signedIn();
    expect(app.moved, isFalse);
    await app.importFromWebsite();
    expect(app.repo!.history(), hasLength(1));
    expect(await app.moveToApp('MK2 DEV · build 32'), isTrue);
    expect(app.moved, isTrue);
    expect(b.movedAt, isNotNull);
    await app.importFromWebsite();
    expect(app.error, contains('moved to the app'));
    app.dispose();
  });

  test('flyttat sedan tidigare: import avstängd direkt efter inloggning', () async {
    final (app, _) = await signedIn(movedAt: DateTime(2026, 10, 3));
    expect(app.moved, isTrue);
    await app.importFromWebsite();
    expect(app.error, contains('moved to the app'));
    expect(app.repo!.history(), isEmpty);
    app.dispose();
  });

  test('okänt (nätfel vid kollen) räknas INTE som "ej flyttat" — import nekas', () async {
    final (app, _) = await signedIn(offline: true);
    expect(app.moved, isNull);
    await app.importFromWebsite();
    expect(app.error, contains('Could not check'));
    expect(app.repo!.history(), isEmpty);
    app.dispose();
  });

  test('backup: alla tabeller, stämplar och tombstones — läsbar som lokal lagring', () async {
    final (app, _) = await signedIn();
    await app.importFromWebsite();
    final w = app.repo!.bodyweight().single;
    await app.deleteBodyweight(w.date); // tombstone ska med
    final j = jsonDecode(app.exportBackup('test')) as Map<String, Object?>;
    expect(j['format'], backupFormat);
    final tables = (j['tables'] as Map).cast<String, Object?>();
    expect(tables.keys.toSet(), Tables.all.toSet());
    final bw = (tables[Tables.bodyweight] as Map).cast<String, Object?>();
    expect((bw.values.single as Map)['del'], isTrue);
    expect((tables[Tables.workouts] as Map), hasLength(1));
    // Samma form som FileLocalStore → en kopia kan läsas tillbaka utan tolkning.
    final items = (tables[Tables.workouts] as Map).values.single as Map;
    expect(items['s'], isA<List<Object?>>());
    expect(items['d'], isA<Map<Object?, Object?>>());
    app.dispose();
  });
}
