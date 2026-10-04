// UNDO försvinner av sig själv efter några sekunder (Niklas 2026-10-04: den
// låg kvar tills man drog bort den — Flutters snackbar med knapp är "persist").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/theme/nanosuit.dart';
import 'package:the_chain/ui/program/program_screen.dart';

import '../app/fake_backend.dart';

void main() {
  testWidgets('borttaget pass: UNDO syns och försvinner av sig själv', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final app = AppController(FakeBackend(mk1: {'sessionOrder': ['A', 'B'], 'restSlots': <int>[]}));
    await tester.runAsync(() async {
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
    });
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(theme: nanosuitThemeData(), home: ProgramScreen(app: app)),
    ));
    await tester.pump();

    await tester.tap(find.byTooltip('More').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Remove session'));
    await tester.pump();
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('UNDO'), findsOneWidget);

    // Timern startar när meddelandet glidit in (~1 s); 2,5 s senare glider det
    // ut. Totalt ~5 s här — en timer på 5 s hade fortfarande visat UNDO.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('UNDO'), findsNothing);
    app.dispose();
  });
}
