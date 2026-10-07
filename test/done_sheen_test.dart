import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/chain_theme.dart';
import 'package:the_chain/theme/cosmic_horror.dart';
import 'package:the_chain/theme/nanosuit.dart';
import 'package:the_chain/theme/surfaces.dart';

Widget _app(ChainTheme theme, bool done) => MaterialApp(
      theme: buildThemeData(theme),
      home: Scaffold(body: DoneSheen(done: done, child: const SizedBox(width: 300, height: 60))),
    );

bool _sheening(WidgetTester t) =>
    find.descendant(of: find.byType(DoneSheen), matching: find.byType(ClipRRect)).evaluate().isNotEmpty;

void main() {
  testWidgets('skimret glider en gång när övningen blir klar, sedan borta', (tester) async {
    await tester.pumpWidget(_app(cosmicHorror, false));
    expect(_sheening(tester), isFalse);
    await tester.pumpWidget(_app(cosmicHorror, true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_sheening(tester), isTrue, reason: 'mitt i skimret');
    await tester.pump(const Duration(milliseconds: 800));
    expect(_sheening(tester), isFalse, reason: 'skimret är över');
  });

  testWidgets('redan klar när passet öppnas: inget skimmer', (tester) async {
    await tester.pumpWidget(_app(cosmicHorror, true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_sheening(tester), isFalse);
  });

  testWidgets('tema utan doneTint (Nanosuit): inget skimmer', (tester) async {
    await tester.pumpWidget(_app(nanosuit, false));
    await tester.pumpWidget(_app(nanosuit, true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_sheening(tester), isFalse);
  });
}
