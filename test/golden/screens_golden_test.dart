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
import 'package:the_chain/theme/eye_tab.dart';
import 'package:the_chain/theme/ambient_life.dart';
import 'package:the_chain/theme/chain_theme.dart';
import 'package:the_chain/theme/cosmic_horror.dart';
import 'package:the_chain/theme/nanosuit.dart';
import 'package:the_chain/ui/chain/round_complete.dart';
import 'package:the_chain/ui/charts/chain_chart.dart';
import 'package:the_chain/ui/workout/workout_screen.dart';

import '../app/app_flow_test.dart' show mk1;
import '../app/fake_backend.dart';

Future<void> _loadSaira() async {
  final loader = FontLoader('Saira')
    ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Saira-Variable.ttf').readAsBytesSync())));
  await loader.load();
  for (final (family, file) in const [('Cinzel', 'Cinzel-Variable.ttf'), ('Martian Mono', 'MartianMono-Variable.ttf')]) {
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync()))))
        .load();
  }
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

/// Rundturen har sin egen bild; övriga passvyns-bilder visar vyn utan den.
Future<void> _tourSeen(AppController app) => app.updateSettings(app.repo!.settings().copyWith(workoutTourSeen: true));

/// ROUND COMPLETE i ett tema; bilderna tas vid [shots] (ms → namn).
Future<void> _round(WidgetTester tester, ThemeData theme, Map<int, String> shots) async {
  await _loadSaira();
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  addTearDown(AmbientLife.reset); // hjärtslagen får inte läcka in i nästa test
  const ids = ['A', 'B', 'C', 'V', 'D', 'E', 'F', 'K', 'V2'];
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: Scaffold(
      body: RoundComplete(
        summary: RoundSummary(
            round: 19,
            start: DateTime(2026, 9, 24),
            end: DateTime(2026, 10, 5),
            trained: 7,
            skipped: 2,
            restDays: 2,
            sets: 74,
            skippedIds: const {SessionId('C'), SessionId('D')}),
        letters: [for (final id in ids) (SessionId(id), id.startsWith('V') ? 'V' : id)],
        restIds: const {SessionId('V'), SessionId('V2')},
        newPrs: 3,
        onDone: () {},
      ),
    ),
  ));
  var elapsed = 0;
  for (final MapEntry(key: ms, value: name) in shots.entries) {
    await tester.pump(Duration(milliseconds: ms - elapsed));
    elapsed = ms;
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('runda klar, Cosmic: hjärtslag, ögonlock, kedjan växer fram', (tester) async {
    // 9 bokstäver: slag 600–2900 (lub/dub var 460 ms), puls –3300, lock
    // 3500–4400 (stängt ~3950), uppväxt 4600–6580, fade 8080–8580 ms.
    await _round(tester, buildThemeData(cosmicHorror), {
      1700: 'round_cosmic_beat',
      3150: 'round_cosmic_lit',
      3800: 'round_cosmic_lid1',
      4250: 'round_cosmic_lid2',
      5400: 'round_cosmic_grow',
      7400: 'round_cosmic_final',
    });
  });

  testWidgets('runda klar: fönster, våg, fallbladsflip, uppbyggnad', (tester) async {
    // 9 bokstäver: våg 600–1950, puls –2350, flip 2550–3450,
    // uppbyggnad 3650–5630, fade 7130–7630 ms.
    await _round(tester, nanosuitThemeData(), {
      1200: 'round_wave',
      2300: 'round_lit',
      2950: 'round_flip1',
      3250: 'round_flip2',
      4500: 'round_rebuild',
      6500: 'round_final',
    });
  });

  testWidgets('adminsidan (påhittade användare)', (tester) async {
    await _loadSaira();
    final now = DateTime.now();
    int ms(int daysAgo) => now.subtract(Duration(days: daysAgo)).millisecondsSinceEpoch;
    String iso(int daysAgo) => now.subtract(Duration(days: daysAgo)).toUtc().toIso8601String();
    final b = FakeBackend()
      ..admin = [
        {
          'email': 'niklgron@gmail.com', 'display_name': 'Niklas', 'created_at': iso(160), 'last_sign_in_at': iso(1),
          'providers': 'email, google', 'web_updated_at': iso(3), 'web_client_seen': {'webDesktop': ms(3), 'app': ms(20)},
          'mk2_workouts': 121, 'mk2_last_workout': ms(0), 'mk2_last_activity': ms(0), 'mk2_devices': 2,
          'mk2_build': 'DEV · build 70', 'moved_at': null,
        },
        {
          'email': 'lt@example.com', 'display_name': 'LT', 'created_at': iso(150), 'last_sign_in_at': iso(2),
          'providers': 'google', 'web_updated_at': iso(2), 'web_client_seen': {'app': ms(2)},
          'mk2_workouts': 0, 'mk2_last_workout': null, 'mk2_last_activity': null, 'mk2_devices': 0, 'mk2_build': null, 'moved_at': null,
        },
        {
          'email': 'johannes@example.com', 'display_name': 'Johannes', 'created_at': iso(161), 'last_sign_in_at': iso(19),
          'providers': 'email', 'web_updated_at': iso(1), 'web_client_seen': {'webMobile': ms(1)},
          'mk2_workouts': 0, 'mk2_last_workout': null, 'mk2_last_activity': null, 'mk2_devices': 0, 'mk2_build': null, 'moved_at': null,
        },
      ];
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => 'niklgron@gmail.com'));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin'));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/admin.png'));
  });

  testWidgets('välkomstskärmen (nytt konto, tomt program)', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: mk1());
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.checkWebsiteData();
    });
    await tester.pumpAndSettle();
    expect(find.text('BRING MY WEBSITE DATA'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/welcome.png'));
  });

  testWidgets('rundturen i passvyn (första gången)', (tester) async {
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
    expect(find.text('LOG each set'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tour_log.png'));
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tour_done.png'));
  });

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
      await _tourSeen(app);
    });
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/chain.png'));
  });

  testWidgets('Cosmic Horror: kedjan (pågående, avklarat, överhoppat), passvyn, settings', (tester) async {
    await _loadSaira();
    // Ögonvarianten slumpas per appstart — låst här, annars byter bilden
    // utseende varannan körning.
    EyeChoice.current = EyeVariant.slit;
    final b = FakeBackend(mk1: {...mk1(), 'restSlots': [2], 'sessionOrder': ['A', 'B', 'C', 'D']});
    final app = _app(b);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    // Animationer PÅ: ådrornas pulser och hjärtslaget ska synas mitt i rörelsen.
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(411.4, 891.4), devicePixelRatio: 2.625, padding: EdgeInsets.only(top: 36, bottom: 24)),
      child: TheChainApp(app: app, emailOf: () => ''),
    ));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
      await _tourSeen(app);
      await app.updateSettings(app.repo!.settings().copyWith(theme: 'cosmic'));
      await app.skipSession(const SessionId('C'), 'Travel');
    });
    app.openWorkout(const SessionId('D'));
    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await frames(41); // mitt i ett hjärtslag (lub)
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/cosmic_chain.png'));
    Future<void> pick(String label) async {
      await tester.ensureVisible(find.text(label).first);
      await frames(6);
      await tester.tap(find.text(label).first);
      await frames(12);
    }

    await pick('B');
    await pick('CHE'); // avklarade A: ärret
    await frames(8);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/cosmic_done.png'));
    await pick('V');
    // D pågår: ögonen i flikens slut — båda varianterna (DEV-knappen växlar).
    await pick('D');
    final eyesButton = find.textContaining('DEV · EYES');
    for (final v in EyeVariant.values) {
      if (EyeChoice.current != v) {
        await tester.ensureVisible(eyesButton);
        await frames(4);
        await tester.tap(eyesButton);
        await tester.ensureVisible(find.text('D').first);
      }
      // Springan är sluten 1,8–5,3 s innan den öppnar sig (slumpat).
      await frames(v == EyeVariant.slit ? 120 : 20);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/cosmic_eyes_${v.name}.png'));
    }
    await tester.ensureVisible(find.text('CONTINUE SESSION'));
    await frames(4);
    await tester.tap(find.text('CONTINUE SESSION'));
    await frames(20);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/cosmic_workout.png'));
    await tester.tap(find.text('LOG').first); // ljusvåg + ådrorna sträcker ut sig
    await frames(20);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/cosmic_burst.png'));
    // Resten av seten + DONE: det mörkgröna glaset (Niklas 2026-10-07: hinnan
    // syntes inte). Skimret självt: done_sheen_test.dart — här hinner kortet
    // scrollas bort och byggas om innan bilden tas.
    while (find.text('LOG').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('LOG').first);
      await tester.tap(find.text('LOG').first);
      await frames(2);
    }
    await tester.ensureVisible(find.text('DONE'));
    await tester.tap(find.text('DONE'));
    await frames(1);
    // Nästa övning öppnas och skjuter undan den klara — scrolla fram den.
    await tester.drag(find.text('WORK').first, const Offset(0, 600));
    await frames(30);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/cosmic_done_card.png'));
    await tester.pumpWidget(const SizedBox());
    AmbientLife.reset();
  });

  testWidgets('temaväljaren: varje tema ritat i sitt eget tema', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: {...mk1(), 'sessionOrder': ['A', 'B']});
    final app = _app(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
      await _tourSeen(app);
      await app.updateSettings(app.repo!.settings().copyWith(theme: 'cosmic'));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/theme_picker.png'));
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
      await _tourSeen(app);
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
      await _tourSeen(app);
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
      await _tourSeen(app);
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
      await _tourSeen(app);
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
      await _tourSeen(app);
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
      await _tourSeen(app);
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
      await _tourSeen(app);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('START SESSION'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ ADD EXERCISE'));
    await tester.pumpAndSettle();
    // "Recent" är öppen från början (senast gjorda övningar); CHEST är kollapsad.
    expect(find.text('Bench Press (BB)'), findsOneWidget, reason: 'bara under Recent');
    await tester.tap(find.text('CHEST'));
    await tester.pumpAndSettle();
    expect(find.text('Bench Press (BB)'), findsNWidgets(2));
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
      await _tourSeen(app);
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
      await _tourSeen(app);
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
      await _tourSeen(app);
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
    await tester.tap(find.text('Training & App Functions'));
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
      await _tourSeen(app);
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
