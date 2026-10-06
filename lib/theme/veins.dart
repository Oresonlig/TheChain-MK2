/// Cosmic Horrors rörliga bakgrund — MK2:s version av MK1:s ådror
/// (_chGenerateVein i index.html). Förgrenade ådror växer in från KANTERNA
/// (MK1: kluster mitt i innehållet tog över, opaciteten fick sänkas två gånger).
/// Bioluminiscenta pulser vandrar längs stammarna, och ibland går ett svagt
/// hjärtslag genom hela nätet.
///
/// Nätet LEVER med användaren ([AmbientLife], Niklas 2026-10-06): det växer
/// ut från rötterna med rundan, och varje LOG skickar en ljusvåg ut genom
/// det. Drivs av samma ~30 fps-takt som Nanosuits väv (HexFieldModel.frame);
/// stilla = nätet i rätt storlek, inga pulser.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ambient_life.dart';
import 'chain_theme.dart';

/// En ådra: punkter med avstånd från sitt systems rot (för tillväxten).
class _Vein {
  _Vein(this.points, this.dist, this.depth, this.system);
  final List<Offset> points;
  final List<double> dist;
  final int depth;
  final int system;

  /// Delen av ådran mellan avstånden [from] och [to] från roten.
  Path? between(double from, double to) {
    if (to <= dist.first || from >= dist.last || to <= from) return null;
    final p = Path();
    var started = false;
    for (var i = 0; i < points.length - 1; i++) {
      final d0 = dist[i], d1 = dist[i + 1];
      if (d1 <= from) continue;
      if (d0 >= to) break;
      final a = d0 < from ? Offset.lerp(points[i], points[i + 1], (from - d0) / (d1 - d0))! : points[i];
      final b = d1 > to ? Offset.lerp(points[i], points[i + 1], (to - d0) / (d1 - d0))! : points[i + 1];
      if (!started) {
        p.moveTo(a.dx, a.dy);
        started = true;
      }
      p.lineTo(b.dx, b.dy);
    }
    return started ? p : null;
  }
}

class _Network {
  _Network(Size s) {
    final r = math.Random(731);
    void grow(int system, Offset start, double angle, {int segs = 16, double reach = 1}) {
      void walk(Offset p, double a, double d, int n, int depth, double branch) {
        if (n <= 0 || depth < 0) return;
        final pts = [p], ds = [d];
        var c = p, ca = a, cd = d;
        for (var i = 0; i < n; i++) {
          final step = ((depth > 1 ? 11 : 6) + r.nextDouble() * 7) * reach;
          ca += (r.nextDouble() - .5) * (.55 + (3 - depth) * .2);
          c += Offset(math.cos(ca), math.sin(ca)) * step;
          cd += step;
          pts.add(c);
          ds.add(cd);
          if (r.nextDouble() < branch && i > 1 && i < n - 1 && depth > 0) {
            final side = r.nextBool() ? -1 : 1;
            walk(c, ca + side * (.5 + r.nextDouble()), cd, math.max(2, (n * (.3 + r.nextDouble() * .35)).floor()), depth - 1,
                branch * .7);
          }
        }
        veins.add(_Vein(pts, ds, depth, system));
        if (cd > reachOf[system]) reachOf[system] = cd;
      }

      walk(start, angle, 0, segs, 3, .45);
    }

    final w = s.width, h = s.height;
    final roots = [
      (Offset(w + 6, -8), 2.35, 16, 1.0), // övre högra hörnet
      (Offset(-6, h + 8), -.78, 16, 1.0), // nedre vänstra hörnet
      (Offset(w + 4, h * .42), math.pi - .25, 11, .85), // höger kant
      (Offset(-4, h * .66), .2, 11, .85), // vänster kant
      (Offset(w * .7, h + 6), -1.9, 10, .8), // nederkant
    ];
    reachOf = List.filled(roots.length, 0);
    for (final (i, (start, angle, segs, reach)) in roots.indexed) {
      grow(i, start, angle, segs: segs, reach: reach);
    }
    for (var i = 0; i < roots.length; i++) {
      trunks.add(veins.firstWhere((v) => v.system == i && v.depth == 3));
    }
    final pr = math.Random(97);
    pulses = [for (var i = 0; i < roots.length; i++) (speed: .0045 + pr.nextDouble() * .003, offset: pr.nextDouble())];
  }

  final veins = <_Vein>[];
  final trunks = <_Vein>[];
  late final List<double> reachOf;
  late final List<({double speed, double offset})> pulses;
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
  final g = AmbientLife.growth(animated: animated);

  // Ådrorna, så långt de vuxit.
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  for (final v in net.veins) {
    final path = v.between(0, g * net.reachOf[v.system]);
    if (path == null) continue;
    stroke
      ..strokeWidth = (.35 + v.depth * .4) * (1 + .25 * beat)
      ..color = Color.lerp(theme.hexLine, theme.hexEnergy, .35 * beat)!
          .withValues(alpha: math.min(1.0, (.22 + v.depth * .1) * (1 + .9 * beat)));
    canvas.drawPath(path, stroke);
  }

  if (animated) {
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;

    // Pulser längs stammarnas vuxna del, varannan inåt, varannan utåt.
    for (final (i, t) in net.trunks.indexed) {
      final grown = math.min(t.dist.last, g * net.reachOf[i]);
      final p = net.pulses[i];
      var at = (p.offset + frame * p.speed) % 1.0;
      if (i.isOdd) at = 1 - at;
      final seg = t.between(at * grown - 12, at * grown);
      if (seg == null) continue;
      canvas
        ..drawPath(seg, glow..color = theme.hexEnergy.withValues(alpha: .45))
        ..drawPath(seg, core..color = theme.hexEnergy.withValues(alpha: .8));
    }

    // LOG: en ljusvåg från rötterna ut genom hela det vuxna nätet.
    for (final age in AmbientLife.burstAges) {
      final front = age / 1000 * 260; // px/s
      final fade = 1 - age / AmbientLife.burstLife;
      glow.color = theme.hexEnergy.withValues(alpha: .55 * fade);
      core.color = theme.hexEnergy.withValues(alpha: .9 * fade);
      for (final v in net.veins) {
        final seg = v.between(front - 26, math.min(front, g * net.reachOf[v.system]));
        if (seg == null) continue;
        canvas
          ..drawPath(seg, glow)
          ..drawPath(seg, core);
      }
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
