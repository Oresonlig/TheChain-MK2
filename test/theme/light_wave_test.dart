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
  /// En modell där vågen just nu är stark över [center] (nedanför rubrikzonen).
  (HexFieldModel, Offset) strongWave(double widthScale) {
    const target = Offset(150, 230);
    final model = HexFieldModel(random: math.Random(1))..layout(const Size(300, 300));
    final center = model.hexes.reduce((a, b) => (a - target).distance < (b - target).distance ? a : b);
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

  test('vågen dämpas bakom rubriken, full styrka nedanför (Niklas 2026-10-15)', () {
    expect(waveCalm(60), lessThanOrEqualTo(.5));
    expect(waveCalm(110), lessThanOrEqualTo(.5));
    expect(waveCalm(140), allOf(greaterThan(.5), lessThan(1)));
    expect(waveCalm(170), 1);
    expect(waveCalm(600), 1);
  });

  testWidgets('Nanosuit: vågen lyser svagare bakom rubriken än nedanför (Niklas 2026-10-23)', (tester) async {
    const scale = 2.0;
    final model = HexFieldModel(random: math.Random(1))..layout(const Size(300, 400));
    Offset? top, low;
    for (var i = 0; i < 4000 && (top == null || low == null); i++) {
      model.step();
      top = low = null;
      for (final h in model.hexes) {
        final e = model.energyAt(h, widthScale: nanosuit.waveWidth);
        if (e <= 0.9 || h.dx < 10 || h.dx > 290 || h.dy < 20 || h.dy > 380) continue;
        if (h.dy < 90 && e < 1.2) top ??= h;
        if (h.dy > 190) low ??= h;
      }
    }
    if (top == null || low == null) fail('ingen våg täckte både rubriken och ytan nedanför');
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)
      ..scale(scale)
      ..drawColor(nanosuit.background, BlendMode.src);
    paintHexField(canvas, model, nanosuit, animated: true);
    final image = (await tester.runAsync(() => rec.endRecording().toImage(600, 800)))!;
    final bytes = (await tester.runAsync(() => image.toByteData()))!;
    double lum(Offset p) {
      final o = ((p.dy * scale).round() * image.width + (p.dx * scale).round()) * 4;
      return (bytes.getUint8(o) * 0.299 + bytes.getUint8(o + 1) * 0.587 + bytes.getUint8(o + 2) * 0.114) / 255;
    }

    expect(lum(top), lessThan(lum(low)), reason: 'rubrikzonen ska vara dämpad');
  });

  test('vågen fäller blad: högst två per svep, som faller ut och försvinner', () {
    final model = HexFieldModel(random: math.Random(3))..layout(const Size(400, 800));
    model.ensurePetals(1);
    final fixed = model.petals.length;
    var maxShed = 0, everShed = false;
    for (var i = 0; i < 6000; i++) {
      model.step();
      maxShed = math.max(maxShed, model.shedCount);
      everShed |= model.shedCount > 0;
    }
    expect(everShed, isTrue, reason: 'svepen ska fälla blad');
    expect(maxShed, lessThanOrEqualTo(HexFieldModel.maxShed));
    expect(model.petals.length - model.shedCount, fixed, reason: 'de fasta bladen återvinns, blir inte fler');
    // Utan nya svep faller de fällda ut och försvinner.
    model.waves.clear();
    for (var i = 0; i < 4000; i++) {
      model.waves.clear();
      model.step();
    }
    expect(model.shedCount, 0);
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
