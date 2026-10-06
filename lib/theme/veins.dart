/// Cosmic Horrors rörliga bakgrund — MK2:s version av MK1:s ådror
/// (_chGenerateVein i index.html). Förgrenade ådror växer in från KANTERNA
/// (MK1: kluster mitt i innehållet tog över, opaciteten fick sänkas två gånger).
/// Bioluminiscenta pulser vandrar längs stammarna, och ibland går ett svagt
/// hjärtslag genom hela nätet. Drivs av samma ~30 fps-takt som Nanosuits väv
/// (HexFieldModel.frame); stilla = bara ådrorna.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'chain_theme.dart';

class _Vein {
  _Vein(this.points, this.depth);
  final List<Offset> points;
  final int depth;
  late final Path path = Path()..addPolygon(points, false);
}

class _Pulse {
  _Pulse(this.trunk, this.speed, this.offset, this.reverse);
  final ui.PathMetric trunk;
  final double speed, offset;
  final bool reverse;
}

class _Network {
  _Network(Size s) {
    final r = math.Random(731);
    List<_Vein> grow(Offset start, double angle, {int segs = 16, double reach = 1}) {
      final out = <_Vein>[];
      void walk(Offset p, double a, int n, int depth, double branch) {
        if (n <= 0 || depth < 0) return;
        final pts = [p];
        var c = p, ca = a;
        for (var i = 0; i < n; i++) {
          final step = ((depth > 1 ? 11 : 6) + r.nextDouble() * 7) * reach;
          ca += (r.nextDouble() - .5) * (.55 + (3 - depth) * .2);
          c += Offset(math.cos(ca), math.sin(ca)) * step;
          pts.add(c);
          if (r.nextDouble() < branch && i > 1 && i < n - 1 && depth > 0) {
            final side = r.nextBool() ? -1 : 1;
            walk(c, ca + side * (.5 + r.nextDouble()), math.max(2, (n * (.3 + r.nextDouble() * .35)).floor()), depth - 1,
                branch * .7);
          }
        }
        out.add(_Vein(pts, depth));
      }

      walk(start, angle, segs, 3, .45);
      return out;
    }

    final w = s.width, h = s.height;
    final systems = [
      grow(Offset(w + 6, -8), 2.35), // övre högra hörnet
      grow(Offset(-6, h + 8), -.78), // nedre vänstra hörnet
      grow(Offset(w + 4, h * .42), math.pi - .25, segs: 11, reach: .85), // höger kant
      grow(Offset(-4, h * .66), .2, segs: 11, reach: .85), // vänster kant
      grow(Offset(w * .7, h + 6), -1.9, segs: 10, reach: .8), // nederkant
    ];
    veins = [for (final v in systems) ...v];
    pulses = [
      for (final (i, v) in systems.indexed)
        if (v.where((x) => x.depth == 3).firstOrNull case final t?)
          _Pulse(t.path.computeMetrics().first, .0045 + r.nextDouble() * .003, r.nextDouble(), i.isOdd),
    ];
  }

  late final List<_Vein> veins;
  late final List<_Pulse> pulses;
}

_Network? _net;
Size _netSize = Size.zero;

/// Nätets hjärtslag: ett svagt lub-dub var 12:e sekund (360 steg à ~33 ms).
double _networkBeat(int frame) {
  final t = (frame % 360) / 40.0; // slaget tar ~1,3 s
  if (t > 1) return 0;
  double pulse(double c, double w) => math.exp(-math.pow((t - c) / w, 2).toDouble());
  return math.min(1.0, pulse(.15, .09) + .6 * pulse(.45, .09));
}

void paintVeins(Canvas canvas, Size size, int frame, ChainTheme theme, {required bool animated}) {
  if (size.isEmpty) return;
  if (_net == null || _netSize != size) {
    _net = _Network(size);
    _netSize = size;
  }
  final net = _net!;
  final beat = animated ? _networkBeat(frame) : 0.0;

  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  for (final v in net.veins) {
    stroke
      ..strokeWidth = .35 + v.depth * .4
      ..color = Color.lerp(theme.hexLine, theme.hexEnergy, .35 * beat)!
          .withValues(alpha: math.min(1.0, (.22 + v.depth * .1) * (1 + .9 * beat)));
    canvas.drawPath(v.path, stroke);
  }

  if (animated) {
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5
      ..color = theme.hexEnergy.withValues(alpha: .45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6
      ..color = theme.hexEnergy.withValues(alpha: .8);
    for (final p in net.pulses) {
      var at = (p.offset + frame * p.speed) % 1.0;
      if (p.reverse) at = 1 - at;
      final len = p.trunk.length;
      final seg = p.trunk.extractPath(math.max(0, at * len - len * .05), at * len);
      canvas
        ..drawPath(seg, glow)
        ..drawPath(seg, core);
    }
  }

  // Vinjett: kanterna sjunker in i mörkret.
  final area = Offset.zero & size;
  canvas.drawRect(
    area,
    Paint()
      ..shader = const RadialGradient(
        radius: .9,
        colors: [Colors.transparent, Color(0x8C000204)],
        stops: [.55, 1],
      ).createShader(area),
  );
}
