// Springans strimlor (eye_tab.dart): en kopia av fliken som målas per strimla
// ska ge EXAKT samma bild som den gamla vägen med 80 byggda kopier
// (Transform.translate + ClipRect per strimla).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/eye_tab.dart';

const _size = Size(120, 44);

/// En flik med text och skarpa kanter — så att varje förskjutning syns.
Widget _tab() => Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF203040), Color(0xFF8090A0)]),
        border: Border.all(color: const Color(0xFFFFCC00), width: 2),
      ),
      alignment: Alignment.center,
      child: const Text('ABC', textDirection: TextDirection.ltr, style: TextStyle(fontSize: 20, color: Color(0xFFFFFFFF))),
    );

class _OldStrip extends CustomClipper<Rect> {
  const _OldStrip(this.x0, this.x1, {required this.upper});
  final double x0, x1;
  final bool upper;
  @override
  Rect getClip(Size s) => upper ? Rect.fromLTRB(x0, 0, x1, s.height / 2) : Rect.fromLTRB(x0, s.height / 2, x1, s.height);
  @override
  bool shouldReclip(_OldStrip old) => true;
}

/// Den gamla vägen (build 105).
Widget _old(List<(double, double, double)> strips) => Stack(children: [
      for (final (x0, x1, d) in strips)
        for (final upper in const [true, false])
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, upper ? -d : d),
              child: ClipRect(clipper: _OldStrip(x0, x1, upper: upper), child: _tab()),
            ),
          ),
    ]);

Future<Uint8List> _pixels(WidgetTester tester, Widget w) async {
  final key = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: RepaintBoundary(key: key, child: SizedBox.fromSize(size: _size, child: w))),
  ));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

void main() {
  for (final lift in [3.0, 7.5, EyeTab.maxLift]) {
    testWidgets('strimlorna = gamla vägen, pixel för pixel (lift $lift)', (tester) async {
      final strips = SlitGeometry(_size, lift).strips.toList();
      final before = await _pixels(tester, _old(strips));
      final after = await _pixels(tester, StripCopies(strips: strips, child: _tab()));
      expect(after.length, before.length);
      var diff = 0;
      for (var i = 0; i < before.length; i++) {
        if (before[i] != after[i]) diff++;
      }
      expect(diff, 0, reason: '$diff bytes skiljer');
      // Och bilden är inte tom (testet mäter något).
      expect(before.any((b) => b != 0), isTrue);
    });
  }

  testWidgets('jämförelsen ser skillnad (1 px fel förskjutning syns)', (tester) async {
    final strips = SlitGeometry(_size, 8).strips.toList();
    final before = await _pixels(tester, _old(strips));
    final off = [for (final (a, b, d) in strips) (a, b, d + 1)];
    final after = await _pixels(tester, StripCopies(strips: off, child: _tab()));
    var diff = 0;
    for (var i = 0; i < before.length; i++) {
      if (before[i] != after[i]) diff++;
    }
    expect(diff, greaterThan(0));
  });

  testWidgets('strimlorna tar inga tryck — de går till fliken under', (tester) async {
    var taps = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: GestureDetector(
          onTap: () => taps++,
          child: SizedBox.fromSize(
            size: _size,
            child: Stack(children: [
              Positioned.fill(child: _tab()),
              Positioned.fill(child: StripCopies(strips: SlitGeometry(_size, 8).strips.toList(), child: _tab())),
            ]),
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(StripCopies), warnIfMissed: false); // missar strimlorna med flit
    expect(taps, 1);
  });
}
