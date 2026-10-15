import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/hex_field.dart';
import 'package:the_chain/theme/nano_sakura.dart';
import 'package:the_chain/theme/nanosuit.dart';

/// Nano Sakuras våg = Nanosuits våg INVERTERAD (Niklas 2026-10-15): på ljus
/// botten ska vågen MÖRKA cellerna, inte lysa vit. Och den ska vara billig —
/// build 122 hackade (ett ritanrop per hex, två gånger per vävsteg).
void main() {
  /// En modell där vågen just nu är stark över [center].
  (HexFieldModel, Offset) strongWave(double widthScale) {
    final model = HexFieldModel(random: math.Random(1))..layout(const Size(300, 300));
    final center = model.hexes.reduce((a, b) => (a - const Offset(150, 150)).distance < (b - const Offset(150, 150)).distance ? a : b);
    for (var i = 0; i < 2000; i++) {
      model.step();
      if (model.energyAt(center, widthScale: widthScale) > 0.9) return (model, center);
    }
    fail('ingen våg passerade');
  }

  testWidgets('Nano Sakura: cellen mitt i vågen är tydligt mörkare än botten', (tester) async {
    const scale = 4.0;
    final (model, center) = strongWave(nanoSakura.waveWidth);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)
      ..scale(scale)
      ..drawColor(nanoSakura.background, BlendMode.src);
    paintHexField(canvas, model, nanoSakura, animated: true);
    final image = (await tester.runAsync(() => rec.endRecording().toImage(1200, 1200)))!;
    final bytes = (await tester.runAsync(() => image.toByteData()))!;

    final x = (center.dx * scale).round(), y = (center.dy * scale).round();
    final o = (y * image.width + x) * 4;
    final cell = (bytes.getUint8(o) * 0.299 + bytes.getUint8(o + 1) * 0.587 + bytes.getUint8(o + 2) * 0.114) / 255;
    final b = nanoSakura.background;
    final background = b.r * 0.299 + b.g * 0.587 + b.b * 0.114;
    expect(cell, lessThan(background - 0.15), reason: 'cellen ($cell) ska vara mörkare än botten ($background)');
  });

  test('Nano Sakura: vågen ritas med ett fåtal anrop, inte ett per hex', () {
    final (model, _) = strongWave(nanoSakura.waveWidth);
    final counter = _CountingCanvas();
    paintHexField(counter, model, nanoSakura, animated: true);
    // 1 för väven + högst en fyllning och en kontur per styrkenivå.
    expect(counter.paths, lessThanOrEqualTo(1 + 2 * lightWaveLevels));
    expect(counter.paths, greaterThan(1), reason: 'vågen ska synas');
  });

  test('Nano Sakura och Nanosuit har samma vågbredd (Niklas 2026-10-15)', () {
    expect(nanoSakura.waveWidth, nanosuit.waveWidth);
  });
}

/// Räknar drawPath-anrop; allt annat ignoreras.
class _CountingCanvas implements Canvas {
  int paths = 0;

  @override
  void drawPath(Path path, Paint paint) => paths++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
