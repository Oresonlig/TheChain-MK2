/// Arctics isflak (Niklas 2026-10-06): plan isyta i mitten för texten, en ring
/// av låg-poly-fasetter runt den, tjockast i underkant som ett flak. Ljuset
/// kommer uppifrån — övre fasetter ljusast, undre mörkast. Isen lyser inifrån
/// vid kanterna (inte i mitten — där står texten). Fasetterna dras ur ett frö,
/// så varje flik får sin egen silhuett men samma flik ser alltid likadan ut.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'chain_theme.dart';

/// Stabilt frö ur en sträng (String.hashCode är inte stabilt mellan körningar).
int floeSeed(String s) {
  var h = 0x811C9DC5;
  for (final u in s.codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0x7FFFFFFF;
  }
  return h;
}

class FloeGeometry {
  FloeGeometry(Size s, int seed) {
    final r = math.Random(seed);
    double j(double a) => r.nextDouble() * a;
    final w = s.width, h = s.height;
    final bev = math.min(8.0, h * .22);
    outline = [
      Offset(bev * .6 + j(2), j(1.2)),
      Offset(w * .37 + j(w * .1), j(1)),
      Offset(w - bev * .8 - j(2), j(1.4)),
      Offset(w, h * .33 + j(h * .1)),
      Offset(w - j(2.5), h * .78),
      Offset(w - bev * 1.1 - j(3), h),
      Offset(w * .5 + j(w * .1), h - j(1.5)),
      Offset(bev * 1.2 + j(3), h),
      Offset(j(2.5), h * .74),
      Offset(0, h * .3 + j(h * .1)),
    ];
    const sx = 4.5, st = 2.5, sb = 5.5;
    const inset = [
      Offset(sx * .7, st),
      Offset(0, st),
      Offset(-sx * .7, st),
      Offset(-sx, 0),
      Offset(-sx, -sb * .4),
      Offset(-sx * .3, -sb),
      Offset(0, -sb),
      Offset(sx * .3, -sb),
      Offset(sx, -sb * .4),
      Offset(sx, 0),
    ];
    face = [for (var i = 0; i < outline.length; i++) outline[i] + inset[i]];
    // Fasettvariation: varje halva av en fasett får egen nyans (låg-poly).
    shade = [for (var i = 0; i < outline.length * 2; i++) (r.nextDouble() - .5) * .14];
    // 1–2 hårfina sprickor från en kant in i ytan.
    cracks = [];
    if (w > 30) {
      final n = 1 + r.nextInt(2);
      for (var k = 0; k < n; k++) {
        final from = face[r.nextInt(face.length)];
        final c = Offset(w / 2, h / 2);
        final len = .3 + r.nextDouble() * .25;
        final mid = Offset.lerp(from, c, len * .5)! + Offset(j(6) - 3, j(4) - 2);
        final end = Offset.lerp(from, c, len)! + Offset(j(8) - 4, j(4) - 2);
        cracks.add([from, mid, end]);
      }
    }
  }

  late final List<Offset> outline;
  late final List<Offset> face;
  late final List<double> shade;
  late final List<List<Offset>> cracks;

  static Path polygon(List<Offset> pts) => Path()..addPolygon(pts, true);
}

/// Konturen som ShapeBorder — för klipp och för pågående-markeringar.
class FloeBorder extends ShapeBorder {
  const FloeBorder({required this.seed});
  final int seed;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      FloeGeometry.polygon(FloeGeometry(rect.size, seed).outline).shift(rect.topLeft);
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
  @override
  ShapeBorder scale(double t) => this;
}

class FloePainter extends CustomPainter {
  const FloePainter({required this.material, required this.seed});

  final RaisedMaterial material;
  final int seed;

  static const _light = Offset(-.35, -.94);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final m = material;
    final g = FloeGeometry(size, seed);
    final outline = FloeGeometry.polygon(g.outline);
    final face = FloeGeometry.polygon(g.face);

    if (m.glow.a > 0) {
      canvas.drawPath(outline, Paint()
        ..color = m.glow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    // Fasetterna: nyans efter hur mycket kanten vänder sig mot ljuset.
    final lit = Color.lerp(m.top, m.highlight.withValues(alpha: 1), .5)!;
    final dark = Color.lerp(m.bottom, Colors.black, .35)!;
    final p = Paint()..isAntiAlias = true;
    final n = g.outline.length;
    for (var i = 0; i < n; i++) {
      final a = g.outline[i], b = g.outline[(i + 1) % n];
      final fa = g.face[i], fb = g.face[(i + 1) % n];
      final e = b - a;
      final len = e.distance;
      if (len == 0) continue;
      final normal = Offset(e.dy / len, -e.dx / len);
      final t = ((normal.dx * _light.dx + normal.dy * _light.dy) + 1) / 2;
      for (var k = 0; k < 2; k++) {
        final v = (t + g.shade[i * 2 + k]).clamp(0.0, 1.0);
        p.color = Color.lerp(dark, lit, v)!.withValues(alpha: m.top.a);
        final tri = k == 0 ? [a, b, fb] : [a, fb, fa];
        canvas.drawPath(Path()..addPolygon(tri, true), p);
      }
    }

    // Isytan: mörk mitt där texten står.
    final bounds = Offset.zero & size;
    canvas.drawPath(face, Paint()
      ..shader = ui.Gradient.linear(bounds.topCenter, bounds.bottomCenter, [m.top, m.bottom]));

    // Inre ljus vid kanterna, klippt till ytan.
    canvas.save();
    canvas.clipPath(face);
    canvas.drawPath(face, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = m.highlight.withValues(alpha: m.highlight.a * .45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    for (final c in g.cracks) {
      canvas.drawPath(
        Path()
          ..moveTo(c[0].dx, c[0].dy)
          ..lineTo(c[1].dx, c[1].dy)
          ..lineTo(c[2].dx, c[2].dy),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7
          ..color = m.highlight.withValues(alpha: m.highlight.a * .35),
      );
    }
    canvas.restore();

    // Ytans kant + skarp ljus överkant + yttre kant.
    canvas.drawPath(face, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6
      ..color = m.highlight.withValues(alpha: m.highlight.a * .3));
    final rim = Path()..moveTo(g.outline[9].dx, g.outline[9].dy);
    for (final q in g.outline.take(4)) {
      rim.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(outline, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = m.edge);
    canvas.drawPath(rim, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round
      ..color = m.highlight);
  }

  @override
  bool shouldRepaint(FloePainter old) => old.material != material || old.seed != seed;
}
