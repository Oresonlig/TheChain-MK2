// "What's new" (Niklas 2026-10-07): en gång efter en uppdatering i STABLE,
// stängs bara med OK/SKIP; ett tryck räcker tills nästa nya text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/app/whats_new.dart';
import 'package:the_chain/theme/nanosuit.dart';
import 'package:the_chain/ui/home_shell.dart';

import 'app_flow_test.dart' show mk1;
import 'fake_backend.dart';

const _notes = [
  WhatsNewNote(build: 107, points: ['a']),
  WhatsNewNote(build: 120, points: ['b']),
];

WhatsNewDecision _d({int build = 110, int? seen, bool history = true}) =>
    decideWhatsNew(build: build, lastSeen: seen, hasHistory: history, notes: _notes);

void main() {
  group('decideWhatsNew', () {
    test('uppdaterad användare som aldrig sett rutan: nyaste texten som gäller bygget', () {
      expect((_d(build: 110) as WhatsNewShow).note.build, 107);
      expect((_d(build: 125) as WhatsNewShow).note.build, 120);
    });
    test('redan sedd: inget', () {
      expect(_d(build: 110, seen: 110), isA<WhatsNewNothing>());
      expect(_d(build: 115, seen: 110), isA<WhatsNewNothing>(), reason: 'ingen ny text sedan 107');
    });
    test('ny text sedan sist: visas', () {
      expect((_d(build: 121, seen: 110) as WhatsNewShow).note.build, 120);
    });
    test('bygge före första texten: inget', () => expect(_d(build: 105), isA<WhatsNewNothing>()));
    test('helt ny användare (ingen historik): tyst markering, ingen ruta', () {
      expect((_d(build: 110, history: false) as WhatsNewSilent).build, 110);
    });
    test('lokalt bygge (build 0): inget', () => expect(_d(build: 0), isA<WhatsNewNothing>()));
  });

  Future<void> shell(WidgetTester tester, WhatsNewStore store, {int build = 107}) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final app = AppController(FakeBackend(mk1: mk1()));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: nanosuitThemeData(),
        home: HomeShell(app: app, email: '', versionLabel: 'MK2 STABLE · build $build', whatsNew: store, build: build),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('UI: visas en gång, går inte att trycka bort utanför, OK stänger och minns', (tester) async {
    final store = MemoryWhatsNewStore();
    await shell(tester, store);
    expect(find.text("WHAT'S NEW"), findsOneWidget);
    await tester.tapAt(const Offset(5, 5)); // utanför rutan
    await tester.pumpAndSettle();
    expect(find.text("WHAT'S NEW"), findsOneWidget, reason: 'tid att läsa: bara OK/SKIP stänger');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text("WHAT'S NEW"), findsNothing);
    expect(store.seen, 107);

    await shell(tester, store); // nästa start
    expect(find.text("WHAT'S NEW"), findsNothing);
  });

  testWidgets('UI: SKIP räcker också — men nästa nya text visas', (tester) async {
    final store = MemoryWhatsNewStore();
    await shell(tester, store);
    expect(find.text("Don't show again"), findsNothing, reason: 'kryssrutan borttagen 2026-10-07');
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text("WHAT'S NEW"), findsNothing);
    expect(store.seen, 107);
    expect(decideWhatsNew(build: 120, lastSeen: store.seen, hasHistory: true, notes: _notes), isA<WhatsNewShow>());
  });

  testWidgets('UI: utan store (DEV/lokalt) visas ingen ruta', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final app = AppController(FakeBackend(mk1: mk1()));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: nanosuitThemeData(),
        home: HomeShell(app: app, email: '', versionLabel: 'MK2 DEV · build 107', devTools: true, build: 107),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text("WHAT'S NEW"), findsNothing);
  });
}
