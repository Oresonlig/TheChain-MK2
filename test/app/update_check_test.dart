// Versionskollen åker med synken (2026-10-03): ny version hittas utan omstart.
// Användarens synkar kollar alltid; passets automatiska högst var tionde minut.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/app/updater.dart';

import 'fake_backend.dart';

void main() {
  late int calls;
  late int latest;
  late bool offline;
  late DateTime now;

  Future<AppController> app() async {
    calls = 0;
    latest = 35;
    offline = false;
    now = DateTime(2026, 10, 3, 12);
    final client = MockClient((_) async {
      calls++;
      if (offline) throw http.ClientException('no network');
      return http.Response('{"build": $latest}', 200);
    });
    final a = AppController(
      FakeBackend(mk1: {'sessionOrder': ['A'], 'restSlots': <int>[]}),
      clock: () => now,
      updater: Updater(channel: 'dev', currentBuild: 35, client: client),
    );
    await a.start();
    await a.signIn('x', 'secret');
    await pumpEventQueue();
    return a;
  }

  test('start kollar; passets automatiska synkar inom tio minuter kollar inte igen', () async {
    final a = await app();
    expect(calls, 1);
    expect(a.update, isNull);
    for (var i = 0; i < 5; i++) {
      now = now.add(const Duration(minutes: 1));
      await a.syncNow(auto: true);
      await pumpEventQueue();
    }
    expect(calls, 1);
    now = now.add(const Duration(minutes: 6));
    await a.syncNow(auto: true);
    await pumpEventQueue();
    expect(calls, 2);
    a.dispose();
  });

  test('SYNC NOW och återkomst kollar alltid — även strax efter förra kollen', () async {
    // Bygge 37: en koll strax innan nya bygget släpptes spärrade alla SYNC NOW
    // i tio minuter.
    final a = await app();
    latest = 36;
    now = now.add(const Duration(minutes: 1));
    await a.syncNow();
    await pumpEventQueue();
    expect(calls, 2);
    expect(a.update?.build, 36);
    await a.onResume();
    await pumpEventQueue();
    expect(calls, 3);
    a.dispose();
  });

  testWidgets('central koll var 3:e minut medan appen syns — utan synk; stoppad i bakgrunden', (tester) async {
    // Uppsättningen behöver riktig tid (pumpEventQueue); timern körs på testets klocka.
    final a = (await tester.runAsync(app))!;
    a.startUpdatePolling();
    a.startUpdatePolling(); // dubbelstart ger inte två timrar
    latest = 36;
    await tester.pump(const Duration(minutes: 3));
    await tester.pump();
    expect(calls, 2);
    expect(a.update?.build, 36);
    a.stopUpdatePolling(); // appen i bakgrunden
    await tester.pump(const Duration(minutes: 30));
    expect(calls, 2);
    a.dispose();
  });

  test('nätfel tar inte bort en redan hittad version ur bannern', () async {
    final a = await app();
    latest = 36;
    now = now.add(const Duration(minutes: 11));
    await a.syncNow();
    await pumpEventQueue();
    offline = true;
    now = now.add(const Duration(minutes: 11));
    await a.syncNow();
    await pumpEventQueue();
    expect(calls, 3);
    expect(a.update?.build, 36);
    expect(a.updateCheckFailed, isTrue);
    a.dispose();
  });

  test('Data & Sync får svaret: senaste med tid, eller kunde inte kolla', () async {
    final a = await app();
    expect(a.updateChecking, isFalse);
    expect(a.updateCheckFailed, isFalse);
    expect(a.updateCheckedAt, now);
    expect(a.update, isNull);

    offline = true;
    now = now.add(const Duration(minutes: 1));
    await a.syncNow();
    await pumpEventQueue();
    expect(a.updateCheckFailed, isTrue);
    expect(a.updateCheckedAt, DateTime(2026, 10, 3, 12)); // senaste lyckade kollen

    offline = false;
    now = now.add(const Duration(minutes: 1));
    await a.syncNow();
    await pumpEventQueue();
    expect(a.updateCheckFailed, isFalse);
    expect(a.updateCheckedAt, now);
    a.dispose();
  });
}
