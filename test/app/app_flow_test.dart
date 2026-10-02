import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/data/sync_engine.dart';
import 'package:the_chain/main.dart';

import 'fake_backend.dart';

final t1 = DateTime(2026, 9, 20, 18).millisecondsSinceEpoch;

Map<String, Object?> mk1() => {
      'sessionOrder': ['A', 'B'],
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
      'weightLog': [
        {'date': '2026-09-20', 'weight': 100.3},
      ],
      'cycles': [
        {
          'id': 1,
          'done': {
            'A': {'timestamp': t1},
          },
        },
      ],
    };

void main() {
  test('fel lösenord ger felmeddelande; rätt ger inloggat läge och synk', () async {
    final b = FakeBackend();
    final app = AppController(b);
    await app.start();
    expect(app.phase, Phase.signedOut);
    await app.signIn('niklas@example.com', 'wrong');
    expect(app.error, contains('Invalid login'));
    await app.signIn('niklas@example.com', 'secret');
    await pumpEventQueue();
    expect(app.phase, Phase.ready);
    expect(app.status, 'Synced');
  });

  test('import från hemsidan → data i appen och på servern', () async {
    final b = FakeBackend(mk1: mk1());
    final app = AppController(b);
    await app.start();
    await app.signIn('x', 'secret');
    await pumpEventQueue();
    await app.importFromWebsite();
    expect(app.repo!.history().length, 1);
    expect(app.repo!.bodyweight().single.kg, 100.3);
    expect(b.server.table(Tables.workouts).length, 1);
    expect(app.status, 'Synced');
  });

  test('inget att importera ger tydligt besked', () async {
    final b = FakeBackend();
    final app = AppController(b);
    await app.start();
    await app.signIn('x', 'secret');
    await pumpEventQueue();
    await app.importFromWebsite();
    expect(app.error, 'No website data found for this account');
  });

  testWidgets('UI: inloggningsskärm → datavy', (tester) async {
    final b = FakeBackend(mk1: mk1());
    final app = AppController(b);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: TheChainApp(app: app, emailOf: () => b.userEmail ?? ''),
    ));
    await tester.runAsync(app.start);
    await tester.pump();
    expect(find.text('SIGN IN'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'niklas@example.com');
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.runAsync(() async {
      await app.signIn('niklas@example.com', 'secret');
      await pumpEventQueue();
    });
    await tester.pump();
    expect(find.text('MK2 · F2 DATA CHECK'), findsOneWidget);
    await tester.runAsync(app.importFromWebsite);
    await tester.pump();
    expect(find.text('Workouts logged'), findsOneWidget);
    expect(find.text('LATEST RECORDS'), findsOneWidget);
    expect(find.text('110 kg × 4'), findsOneWidget);
  });
}
