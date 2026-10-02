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

void main() {
  testWidgets('login', (tester) async {
    await _loadSaira();
    final b = FakeBackend();
    final app = AppController(b);
    await _phone(tester, TheChainApp(app: app, emailOf: () => ''));
    await tester.runAsync(app.start);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/login.png'));
  });

  testWidgets('kedjevyn', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: {...mk1(), 'restSlots': [2], 'sessionOrder': ['A', 'B', 'C', 'D']});
    final app = AppController(b);
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
    final app = AppController(b);
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
      final app = AppController(b);
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
    final app = AppController(b);
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
    final app = AppController(b);
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

  testWidgets('dev home efter import', (tester) async {
    await _loadSaira();
    final b = FakeBackend(mk1: mk1());
    final app = AppController(b);
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
}
