// Lokal granskning av F2-skärmarna. Kör: `node tool/flutter.mjs test test/golden
// --run-skipped --update-goldens` → test/golden/goldens/*.png
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/domain/domain.dart';
import 'package:the_chain/main.dart';
import 'package:the_chain/ui/charts/chain_chart.dart';
import 'package:the_chain/ui/workout/workout_screen.dart';

import '../app/app_flow_test.dart' show mk1;
import '../app/fake_backend.dart';

Future<void> _loadSaira() async {
  final loader = FontLoader('Saira')
    ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Saira-Variable.ttf').readAsBytesSync())));
  await loader.load();
  // Ikontypsnittet ur den lokala SDK:n, så att ikoner syns i bilderna.
  final icons = File('../.flutter-sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  }
}

Future<void> _phone(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MediaQuery(
    data: const MediaQueryData(
      size: Size(411.4, 891.4),
      devicePixelRatio: 2.625,
      padding: EdgeInsets.only(top: 36, bottom: 24),
      disableAnimations: true,
    ),
    child: app,
  ));
}

/// Ingen synk-fördröjning: timern töms av pumpAndSettle i stället för att
/// ligga kvar när testet slutar.
AppController _app(FakeBackend b) => AppController(b, syncDelay: Duration.zero);

void main() {
  testWidgets('login', (tester) async {
    await _loadSaira();
    final b = FakeBackend();
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(app.start);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/login.png'));
  });

  testWidgets('login_reset', (tester) async {
    await _loadSaira();
    final b = FakeBackend();
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(app.start);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'niklas@example.com');
    await tester.tap(find.text('Forgot password?'));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/login_reset.png'));
  });

  testWidgets('kedjevyn', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: {...mk1(), 'restSlots': [2], 'sessionOrder': ['A', 'B', 'C', 'D']});
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/chain.png'));
  });

  testWidgets('avslutat pass: låst, COPY + UNDO', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: {...mk1(), 'sessionOrder': ['A', 'B']});
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHE').first); // pass A (avslutat) i slidern
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/done.png'));
  });

  for (final tab in ['WEIGHT', 'PROGRESS', 'SETTINGS']) {
    testWidgets('flik $tab', (tester) async {
      await _loadSaira();
      final b = FakeBackend(mk1: {...mk1(), 'sessionOrder': ['A', 'B']});
      final app = _app(b);
      await _phone(tester, TheChainApp(app: app, emailOf: () => 'niklas@example.com'));
      await tester.runAsync(() async {
        await app.start();
        await app.signIn('x', 'secret');
        await pumpEventQueue();
        await app.importFromWebsite();
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tab_${tab.toLowerCase()}.png'));
    });
  }

  testWidgets('fortsätt-listen när pass pågår', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: {...mk1(), 'sessionOrder': ['A', 'B']});
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    app.openWorkout(const SessionId('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WEIGHT'));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUE'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/continue_bar.png'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('FINISH SESSION'), findsOneWidget);
  });

  testWidgets('passvyn', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: {...mk1(), 'sessionOrder': ['A', 'B']});
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('START SESSION'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/workout.png'));
  });

  testWidgets('passvyn: FAIL + GOAL, minus-par, släckt DONE; botten med glas', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: {...mk1(), 'sessionOrder': ['A', 'B']});
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('START SESSION'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '100');
    await tester.enterText(fields.at(1), '3');
    await tester.tap(find.text('LOG').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('FAIL').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(3), '4'); // GOAL-fältet efter setets tre fält
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/workout_fail.png'));
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/workout_bottom.png'));
  });

  testWidgets('passvyn: Last med WARM-UP/WORK + förra gångens goal', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: {...mk1(), 'sessionOrder': ['A', 'B']});
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
      // Förra passet: uppvärmning + arbetsset där sista failade mot mål 5.
      final wc = app.openWorkout(const SessionId('A'));
      wc.addSet(wc.workout.exercises.first.id, SetKind.warmup);
      wc.addSet(wc.workout.exercises.first.id, SetKind.warmup);
      final row = wc.workout.exercises.first;
      final work = row.sets.where((s) => s.kind == SetKind.work).toList();
      for (final s in row.sets) {
        final warm = s.kind == SetKind.warmup;
        wc.setValues(row.id, s.id, SetValues(weight: warm ? 60 : 100, reps: warm ? 8 : (s == work.last ? 3 : 5)));
        wc.toggleLog(row.id, s.id);
      }
      wc.toggleFailed(row.id, work.last.id);
      wc.setTarget(row.id, work.last.id, const SetValues(reps: 5));
      wc.toggleLog(row.id, work.last.id); // LOG FAIL
      wc.markDone(row.id);
      for (final r in wc.workout.exercises.skip(1)) {
        wc.skip(r.id);
      }
      await wc.finish();
    });
    await tester.pumpAndSettle();
    final wc2 = app.openWorkout(const SessionId('A'));
    tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => WorkoutScreen(controller: wc2)));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/workout_last.png'));
  });

  testWidgets('övningsväljaren: kollapsade grupper, en öppnad', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: {...mk1(), 'sessionOrder': ['A', 'B']});
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('START SESSION'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ ADD EXERCISE'));
    await tester.pumpAndSettle();
    expect(find.text('Bench Press (BB)'), findsNothing, reason: 'kollapsat');
    await tester.tap(find.text('CHEST'));
    await tester.pumpAndSettle();
    expect(find.text('Bench Press (BB)'), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/picker.png'));
  });

  // Realistisk historik: bänk stiger till PR 130, två månader runt halva vikten,
  // ett uppehåll på åtta veckor, sedan tillbaka. Vikt 92 → 86 med brus.
  Map<String, Object?> chartData() {
    final now = DateTime.now();
    final log = <Map<String, Object?>>[];
    final weights = <Map<String, Object?>>[];
    var day = now.subtract(const Duration(days: 300));
    var i = 0;
    while (day.isBefore(now.subtract(const Duration(days: 2)))) {
      final age = now.difference(day).inDays;
      final inGap = age < 110 && age > 54;
      if (!inGap) {
        final w = age > 200
            ? 100 + (300 - age) / 100 * 25 // upp mot 125
            : age > 180
                ? 130.0 // PR-tiden
                : age > 120
                    ? 65.0 + (i % 3) * 2.5 // "vad hände här?"
                    : 105.0 + (54 - age.clamp(0, 54)) / 54 * 10;
        log.add({
          'passId': 'A',
          'timestamp': day.millisecondsSinceEpoch,
          'exercises': [
            {
              'id': 'A1',
              'name': 'Bench Press (BB)',
              'exId': 'ex_bench_press_bb',
              'measure': 'weight',
              'sets': [
                {'warmup': true, 'weight': 60, 'reps': 8},
                {'warmup': false, 'weight': (w / 2.5).round() * 2.5, 'reps': age > 180 && age <= 200 ? 1 + (i % 2) : 5},
              ],
            },
          ],
        });
      }
      weights.add({
        'date': '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        'weight': double.parse((92 - (300 - age) / 300 * 6 + ((i * 7) % 5 - 2) * 0.35).toStringAsFixed(1)),
      });
      day = day.add(Duration(days: 4 + i % 3));
      i++;
    }
    return {...mk1(), 'sessionOrder': ['A', 'B'], 'log': log, 'weightLog': weights, 'weightGoal': 85, 'weightGoalEnabled': true};
  }

  Future<AppController> chartApp(WidgetTester tester) async {
    await _loadSaira();
    final app = _app(FakeBackend(mk1: chartData()));
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('viktgrafen', (tester) async {
    await chartApp(tester);
    await tester.tap(find.text('WEIGHT'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/chart_weight.png'));
  });

  testWidgets('PR-grafen: ALL + tumme på en punkt, sedan 3M', (tester) async {
    await chartApp(tester);
    await tester.tap(find.text('PROGRESS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHEST'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press (BB)'));
    await tester.pumpAndSettle();
    final chart = find.byType(ChainChart);
    await tester.tapAt(tester.getTopLeft(chart) + Offset(tester.getSize(chart).width * .3, 120));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/chart_pr.png'));
    await tester.tap(find.text('3M'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/chart_pr_3m.png'));
  });

  testWidgets('dev home efter import', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: mk1());
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => b.userEmail ?? ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('niklas@example.com', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/dev_home.png'));
  });

  testWidgets('settings: hubb + Data & Sync', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: mk1());
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => b.userEmail ?? ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('niklas@example.com', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_hub.png'));
    await tester.tap(find.text('Data & Sync'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_data.png'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Training'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/settings_training.png'));
  });

  testWidgets('ny användare: tom kedja → BUILD YOUR PROGRAM', (tester) async {
    await _loadSaira();
    final b = FakeBackend();
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
    });
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/chain_empty.png'));
  });

  testWidgets('programbyggaren: kedjan, passet, väljaren, egenskaper', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: {...mk1(), 'restSlots': [2], 'sessionOrder': ['A', 'B', 'C', 'D']});
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => b.userEmail ?? ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('niklas@example.com', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pumpAndSettle();
    // Ett pågående pass: byggaren säger att ändringar gäller nästa gång.
    await tester.tap(find.text('START SESSION'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to the chain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Program'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/program.png'));

    await tester.tap(find.textContaining('exercises').at(1));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/program_session.png'));

    await tester.tap(find.text('+ ADD EXERCISES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHEST'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press (DB)'));
    await tester.tap(find.text('Cable Crossover'));
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/program_picker.png'));
    await tester.tap(find.text('ADD 2'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cable Crossover'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<Measure>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reps').last);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/program_exercise.png'));
  });
}
