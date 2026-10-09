// Cosmic Horrors fem ärr och fem klösmärken sida vid sida (Niklas 2026-10-09).
// Kör: `node tool/flutter.mjs test test/golden/marks_golden_test.dart --run-skipped --update-goldens`
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/cosmic_horror.dart';
import 'package:the_chain/ui/chain/chain_strip.dart';

/// Frö nummer [nth] som ger [variant] (två per variant: spegelvändning och jitter syns).
int _seedFor(int variant, [int nth = 0]) {
  for (var s = 0;; s++) {
    if (MarkChoice.mix(s) % MarkChoice.variants == variant && nth-- == 0) return s;
  }
}

void main() {
  testWidgets('ärr och klösmärken, variant 1–5', (tester) async {
    await (FontLoader('Cinzel')
          ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Cinzel-Variable.ttf').readAsBytesSync()))))
        .load();
    const c = cosmicHorror;
    Widget tab(CustomPainter p, String label, {double width = 120}) => Padding(
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            width: width,
            height: 46,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CustomPaint(
                foregroundPainter: p,
                child: Container(
                  color: c.backgroundGlow,
                  alignment: Alignment.center,
                  child: Text(label, style: TextStyle(fontFamily: 'Cinzel', fontSize: 18, color: c.textFaint)),
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: c.background,
        body: Center(
          child: RepaintBoundary(
            key: const ValueKey('marks'),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final (short, nth) in [(false, 0), (false, 1), (true, 0)])
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var v = 0; v < 5; v++)
                    tab(ScarPainter(c.accent, seed: _seedFor(v, nth)), short ? 'C' : 'B  BACK', width: short ? 46 : 120),
                ]),
              for (final short in [false, true])
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var v = 0; v < 5; v++)
                    tab(ClawPainter(c.fail, tab: true, seed: _seedFor(v)), short ? 'C' : 'B  BACK', width: short ? 46 : 120),
                ]),
            ]),
          ),
        ),
      ),
    ));
    await expectLater(find.byKey(const ValueKey('marks')), matchesGoldenFile('goldens/cosmic_marks.png'));
  });
}
