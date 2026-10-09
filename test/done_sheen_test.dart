import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/chain_theme.dart';
import 'package:the_chain/theme/cosmic_horror.dart';
import 'package:the_chain/theme/nanosuit.dart';
import 'package:the_chain/theme/surfaces.dart';

Widget _app(ChainTheme theme, bool done, {bool repeat = false, int seed = 1}) => MaterialApp(
      theme: buildThemeData(theme),
      home: Scaffold(
        body: DoneSheen(
          done: done,
          repeat: repeat,
          random: math.Random(seed),
          child: const SizedBox(width: 300, height: 60),
        ),
      ),
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

  testWidgets('pågående pass: skimret återkommer efter ~4 s paus', (tester) async {
    await tester.pumpWidget(_app(cosmicHorror, false, repeat: true));
    await tester.pumpWidget(_app(cosmicHorror, true, repeat: true));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(_sheening(tester), isFalse, reason: 'första svepet klart');
    await tester.pump(const Duration(milliseconds: 3000)); // < 3,6 s paus
    expect(_sheening(tester), isFalse, reason: 'mitt i pausen');
    await tester.pump(const Duration(milliseconds: 1500)); // paus slut (≤ 4,4 s)
    await tester.pump(const Duration(milliseconds: 100));
    expect(_sheening(tester), isTrue, reason: 'nästa svep');
  });

  testWidgets('pågående pass, redan klar: första svepet inom en paus', (tester) async {
    await tester.pumpWidget(_app(cosmicHorror, true, repeat: true));
    var seen = false;
    for (var i = 0; i < 52 && !seen; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      seen = _sheening(tester);
    }
    expect(seen, isTrue);
  });

  testWidgets('osynkat: två kort börjar inte samtidigt', (tester) async {
    Future<int> start(int seed) async {
      await tester.pumpWidget(_app(cosmicHorror, true, repeat: true, seed: seed));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (_sheening(tester)) return i;
      }
      return -1;
    }

    final a = await start(11);
    await tester.pumpWidget(const SizedBox());
    final b = await start(4242);
    expect(a, isNot(b));
  });

  testWidgets('kort som inte är klart: inget återkommande skimmer', (tester) async {
    await tester.pumpWidget(_app(cosmicHorror, false, repeat: true));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(_sheening(tester), isFalse);
    }
  });

  testWidgets('tema utan doneTint (Nanosuit): inget skimmer', (tester) async {
    await tester.pumpWidget(_app(nanosuit, false));
    await tester.pumpWidget(_app(nanosuit, true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_sheening(tester), isFalse);
  });
}
