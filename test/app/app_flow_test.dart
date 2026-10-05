import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/app/updater.dart';
import 'package:the_chain/data/sync_engine.dart';
import 'package:the_chain/domain/domain.dart';
import 'package:the_chain/main.dart';

import 'fake_backend.dart';

double? personalRecordsOf(AppController app) =>
    personalRecords(app.repo!.history())[const ExerciseId('ex_bench_press_bb')]?.value;

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

  test('fullt minne under synk: synken fastnar inte, nästa synk fungerar', () async {
    final b = FakeBackend();
    final app = AppController(b);
    await app.start();
    await app.signIn('x', 'secret');
    await pumpEventQueue();
    b.diskFull = true;
    await app.syncNow();
    expect(app.busy, isFalse);
    expect(app.status, contains('Could not save'));
    b.diskFull = false;
    await app.syncNow();
    expect(app.status, 'Synced');
  });

  test('Google: inloggad; avbrutet = inget besked; fel = besked', () async {
    final b = FakeBackend()..google = 'cancel';
    final app = AppController(b);
    await app.start();
    await app.signInWithGoogle();
    expect(app.error, isNull);
    expect(app.phase, Phase.signedOut);
    b.google = 'ApiException: 10';
    await app.signInWithGoogle();
    expect(app.error, contains('ApiException: 10'));
    b.google = 'ok';
    await app.signInWithGoogle();
    await pumpEventQueue();
    expect(app.error, isNull);
    expect(app.phase, Phase.ready);
  });

  group('glömt lösenord', () {
    test('kod + nytt lösenord → inloggad, gamla lösenordet ogiltigt', () async {
      final b = FakeBackend();
      final app = AppController(b);
      await app.start();
      expect(await app.sendResetCode('  '), isFalse);
      expect(app.error, contains('email first'));
      expect(await app.sendResetCode('niklas@example.com'), isTrue);
      expect(app.error, isNull);
      await app.resetPassword('niklas@example.com', '123 456', 'newpass99', 'newpass99');
      await pumpEventQueue();
      expect(app.error, isNull);
      expect(app.phase, Phase.ready);
      expect(b.password, 'newpass99');
      expect(b.storeOpens, 1);
    });

    test('valideras före servern: kort, olika, saknad kod', () async {
      final b = FakeBackend();
      final app = AppController(b);
      await app.start();
      await app.sendResetCode('x@y.z');
      await app.resetPassword('x@y.z', '', 'newpass99', 'newpass99');
      expect(app.error, contains('code'));
      await app.resetPassword('x@y.z', '123456', 'short', 'short');
      expect(app.error, contains('at least 8'));
      await app.resetPassword('x@y.z', '123456', 'newpass99', 'newpass98');
      expect(app.error, contains("don't match"));
      expect(b.sentCode, '123456', reason: 'koden ska inte förbrukas av lokala fel');
      expect(app.phase, Phase.signedOut);
    });

    test('fel kod → kvar utloggad med besked', () async {
      final b = FakeBackend();
      final app = AppController(b);
      await app.start();
      await app.sendResetCode('x@y.z');
      await app.resetPassword('x@y.z', '999999', 'newpass99', 'newpass99');
      await pumpEventQueue();
      expect(app.error, contains('expired or is invalid'));
      expect(app.phase, Phase.signedOut);
    });

    test('appen öppnas inte medan lösenordet sätts; misslyckas det loggas man ut', () async {
      final b = FakeBackend()..failPasswordUpdate = true;
      final app = AppController(b);
      await app.start();
      await app.sendResetCode('x@y.z');
      await app.resetPassword('x@y.z', '123456', 'samepass1', 'samepass1');
      await pumpEventQueue();
      expect(app.error, contains('Password not changed'));
      expect(app.phase, Phase.signedOut);
      expect(b.userId, isNull);
      expect(b.storeOpens, 0);
    });
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
    expect(find.text('No program yet'), findsOneWidget); // före import
    await tester.runAsync(app.importFromWebsite);
    await tester.pump();
    expect(find.textContaining('Round'), findsOneWidget);
    expect(find.text('START SESSION'), findsOneWidget);
  });

  test('appstart med sparad inloggning: start() + initialSession öppnar data EN gång', () async {
    final b = FakeBackend(mk1: mk1())..restoreSession();
    final app = AppController(b);
    final started = app.start();
    b.emitAuthEvent(); // kommer medan start() fortfarande öppnar
    b.emitAuthEvent(); // och en tokenRefresh för säkerhets skull
    await started;
    await pumpEventQueue();
    expect(b.storeOpens, 1);
    expect(app.phase, Phase.ready);
  });

  test('utloggning nollställer kontots läge (fel och synkstatus följer inte med till inloggningen)', () async {
    final b = FakeBackend(mk1: mk1());
    final app = AppController(b);
    await app.start();
    await app.signIn('x', 'secret');
    await pumpEventQueue();
    await app.importFromWebsite();
    expect(app.status, 'Synced');
    app.error = 'Import failed: something';
    await app.signOut();
    await pumpEventQueue();
    expect(app.phase, Phase.signedOut);
    expect(app.error, isNull);
    expect(app.status, isNull);
    expect(app.repo, isNull);
  });

  testWidgets('UI: utloggning med en vy ovanpå (passvyn) → inloggningen syns, inte en evig snurra', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final b = FakeBackend(mk1: mk1());
    final app = AppController(b);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: TheChainApp(app: app, emailOf: () => ''),
    ));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pump();
    await tester.tap(find.text('START SESSION'));
    await tester.pumpAndSettle();
    expect(find.text('FINISH SESSION'), findsOneWidget);

    // Nytt bygge medan passet är öppet: diskret notis i passvyn, ingen knapp.
    app.update = const UpdateInfo(build: 99, apkUrl: 'x');
    await tester.runAsync(app.syncNow); // synken meddelar lyssnarna
    await tester.pump();
    expect(find.text('Build 99 ready · update after the session'), findsOneWidget);
    expect(find.text('UPDATE'), findsNothing);

    await tester.runAsync(app.signOut);
    await tester.pumpAndSettle();
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('FINISH SESSION'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('UI: helt pass — starta, logga, klar, avsluta, tillbaka till kedjan', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final b = FakeBackend(mk1: {
      'sessionOrder': ['A'],
      'restSlots': <int>[],
      'weightLog': [
        {'date': '2026-09-20', 'weight': 100.0},
      ],
    });
    final app = AppController(b);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: TheChainApp(app: app, emailOf: () => ''),
    ));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pump();
    await tester.tap(find.text('START SESSION'));
    await tester.pumpAndSettle();
    expect(find.text('Bench Press (BB)'), findsOneWidget);
    expect(find.text('FINISH SESSION'), findsOneWidget);

    // Första övningen är expanderad: skriv vikt + reps i sista arbetssetet och logga.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(fields.evaluate().length - 3), '100');
    await tester.enterText(fields.at(fields.evaluate().length - 2), '5');
    await tester.tap(find.text('LOG').last);
    await tester.pump();
    expect(find.byIcon(Icons.check), findsWidgets);

    // DONE är släckt så länge uppvärmningarna är ologgade: ta bort dem med "−".
    await tester.tap(find.text('DONE').last);
    await tester.pump();
    expect(app.repo!.activeWorkouts().single.exercises.first.status, ExerciseStatus.open);
    WorkoutExercise first() => app.repo!.activeWorkouts().single.exercises.first;
    for (var i = 0; i < 10 && !first().canMarkDone; i++) {
      final hasWarm = first().sets.any((s) => s.kind == SetKind.warmup && !s.isLogged);
      await tester.tap(hasWarm ? find.byIcon(Icons.remove).first : find.byIcon(Icons.remove).last);
      await tester.pump();
    }
    expect(first().sets.map((s) => s.isLogged), [true]); // bara det loggade setet kvar
    await tester.tap(find.text('DONE').last);
    await tester.pump();
    // Resten hoppas över.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('SKIP').last);
      await tester.pump();
    }
    await tester.tap(find.text('FINISH SESSION'));
    await tester.pumpAndSettle();
    // "How did it feel?" (på som standard).
    await tester.enterText(find.byType(TextField).last, 'Slept 4 h');
    await tester.tap(find.text('Finish'));
    await tester.runAsync(() => pumpEventQueue());
    await tester.pumpAndSettle();
    expect(find.text('TRAIN AGAIN'), findsNothing);
    final h = app.repo!.history();
    expect(h.length, 1);
    expect((h.single as WorkoutEntry).workout.note, 'Slept 4 h');
    final bench = personalRecordsOf(app);
    expect(bench, 100);
  });
}
