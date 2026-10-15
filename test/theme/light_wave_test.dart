import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/theme/hex_field.dart';
import 'package:the_chain/theme/nano_sakura.dart';

/// Vågen på ljus botten ska MÖRKNA väven, inte lysa vit (Niklas 2026-10-15:
/// den rosa fyllningen slutade innanför kanten, så den pärlvita botten lyste
/// igenom springan mellan hexagonerna och vågen lästes som vita linjer).
/// Mäter springan mellan två grannar mitt i vågen: den ska vara mörkare än botten.
void main() {
  testWidgets('Nano Sakura: springan i vågen är mörkare än botten', (tester) async {
    const area = Size(300, 300), scale = 4.0;
    final model = HexFieldModel(random: math.Random(1))..layout(area);
    const s = HexFieldModel.size;
    final center = model.hexes.reduce((a, b) => (a - const Offset(150, 150)).distance < (b - const Offset(150, 150)).distance ? a : b);
    final neighbour = center + Offset(s * 1.5, math.sqrt(3) * s / 2);

    // Kör tills vågen är stark över båda grannarna.
    var found = false;
    for (var i = 0; i < 2000 && !found; i++) {
      model.step();
      found = model.energyAt(center, widthScale: nanoSakura.waveWidth) > 0.9 &&
          model.energyAt(neighbour, widthScale: nanoSakura.waveWidth) > 0.9;
    }
    expect(found, isTrue, reason: 'ingen våg passerade');

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)
      ..scale(scale)
      ..drawColor(nanoSakura.background, BlendMode.src);
    paintHexField(canvas, model, nanoSakura, animated: true);
    final image = await tester.runAsync(() => rec.endRecording().toImage((area.width * scale).round(), (area.height * scale).round()));
    final bytes = (await tester.runAsync(() => image!.toByteData()))!;

    double lum(Offset p) {
      final x = (p.dx * scale).round(), y = (p.dy * scale).round();
      final o = (y * image!.width + x) * 4;
      return (bytes.getUint8(o) * 0.299 + bytes.getUint8(o + 1) * 0.587 + bytes.getUint8(o + 2) * 0.114) / 255;
    }

    final gap = lum((center + neighbour) / 2); // mitt på den delade kanten
    final b = nanoSakura.background;
    final background = b.r * 0.299 + b.g * 0.587 + b.b * 0.114;
    expect(gap, lessThan(background - 0.15), reason: 'springan ($gap) ska vara tydligt mörkare än botten ($background)');
  });
}
