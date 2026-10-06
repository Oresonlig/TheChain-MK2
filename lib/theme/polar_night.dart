/// Arctics rörliga bakgrund (Niklas 2026-10-06): låg markdimma som driver
/// långsamt, frost som växer in från två hörn och andas, och ett fint frostkorn
/// så att inget är platt. Drivs av samma ~30 fps-takt som Nanosuits väv
/// (HexFieldModel.frame). Stilla (ambient av / minska rörelse) = frame 0.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'chain_theme.dart';

/// Frostkristall i en 120×120-ruta (hörnet i 0,0): en stam med grenar.
const _fern = [
  (0.0, 8.0, 70.0, 30.0), (18.0, 13.0, 26.0, 2.0), (18.0, 13.0, 22.0, 26.0), (38.0, 19.0, 50.0, 6.0),
  (38.0, 19.0, 44.0, 34.0), (56.0, 25.0, 66.0, 14.0), (8.0, 0.0, 34.0, 70.0), (14.0, 18.0, 2.0, 26.0),
  (14.0, 18.0, 28.0, 22.0), (21.0, 38.0, 6.0, 48.0), (21.0, 38.0, 36.0, 44.0), (28.0, 56.0, 16.0, 66.0),
  (0.0, 0.0, 56.0, 56.0), (30.0, 30.0, 30.0, 14.0), (30.0, 30.0, 14.0, 30.0), (44.0, 44.0, 46.0, 30.0),
  (44.0, 44.0, 30.0, 46.0),
];

ui.Image? _grain;

/// Frostkornet: en liten brusbild, gjord en gång, ritad som mönster.
ui.Image _grainImage() {
  final cached = _grain;
  if (cached != null) return cached;
  const n = 96;
  final r = math.Random(42);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final p = Paint();
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final a = r.nextDouble() * .09;
      p.color = (r.nextBool() ? Colors.white : Colors.black).withValues(alpha: a);
      c.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), p);
    }
  }
  final pic = rec.endRecording();
  final img = pic.toImageSync(n, n);
  pic.dispose();
  return _grain = img;
}

/// [grain] = av i glasets blurrade kopia (blurren äter det ändå).
void paintPolarNight(Canvas canvas, Size size, int frame, ChainTheme theme, {bool grain = true}) {
  if (size.isEmpty) return;
  final w = size.width, h = size.height;
  final f = frame.toDouble();

  // Markdimma: tre stora mjuka band som driver åt var sitt håll.
  for (final (k, (y, a, speed)) in const [(.97, .16, .004), (.86, .11, -.003), (.55, .05, .0025)].indexed) {
    final cx = w * (.5 + .32 * math.sin(f * speed + k * 2.1));
    final rect = Rect.fromCenter(center: Offset(cx, h * y), width: w * 1.3, height: 190);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFF96C8E1).withValues(alpha: a),
          const Color(0xFF96C8E1).withValues(alpha: 0),
        ]).createShader(rect),
    );
  }

  // Frost i två hörn som andas.
  final breathe = .55 + .45 * (.5 + .5 * math.sin(f * .023));
  final fern = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = .9
    ..strokeCap = StrokeCap.round
    ..color = theme.hexLine.withValues(alpha: theme.hexLine.a * breathe);
  void corner(Offset at, double scale, double angle) {
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(angle)
      ..scale(scale);
    for (final (x1, y1, x2, y2) in _fern) {
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), fern);
    }
    canvas.restore();
  }

  corner(Offset.zero, 1.15, 0);
  corner(Offset(w, h), 1.3, math.pi);

  if (grain) {
    final img = _grainImage();
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = ImageShader(img, TileMode.repeated, TileMode.repeated, Matrix4.identity().storage),
    );
  }
}
