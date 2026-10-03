// Versionskollen åker med synken (2026-10-03): ny version hittas utan omstart,
// men högst var tionde minut — under ett pass synkar appen efter varje set.
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

  test('start kollar en gång; synkar inom tio minuter kollar inte igen', () async {
    final a = await app();
    expect(calls, 1);
    expect(a.update, isNull);
    for (var i = 0; i < 5; i++) {
      now = now.add(const Duration(minutes: 1));
      await a.syncNow();
      await pumpEventQueue();
    }
    expect(calls, 1);
    a.dispose();
  });

  test('ny version efter tio minuter hittas av en vanlig synk, utan omstart', () async {
    final a = await app();
    latest = 36;
    now = now.add(const Duration(minutes: 11));
    await a.onResume();
    await pumpEventQueue();
    expect(calls, 2);
    expect(a.update?.build, 36);
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
    a.dispose();
  });
}
