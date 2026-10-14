/// Cosmic Horrors rörliga bakgrund — MK2:s version av MK1:s ådror
/// (_chGenerateVein i index.html). Förgrenade ådror växer in från KANTERNA
/// (MK1: kluster mitt i innehållet tog över, opaciteten fick sänkas två gånger).
/// Bioluminiscenta pulser vandrar längs stammarna, och ibland går ett svagt
/// hjärtslag genom hela nätet.
///
/// Nätet SVARAR på användaren ([AmbientLife], Niklas 2026-10-06): alltid
/// fullvuxet, och varje LOG skickar en ljusvåg ut genom det medan ådrorna
/// sträcker ut sig och sedan drar sig tillbaka. Drivs av samma ~30 fps-takt
/// som Nanosuits väv (HexFieldModel.frame); stilla = vilande nät, inga pulser.
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

  /// Grenarna som skjuter ut från den här ådran, i ordning längs den
  /// (grenens dist.first = avståndet där den lämnar ådran).
  final branches = <_Vein>[];

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
      _Vein? walk(Offset p, double a, double d, int n, int depth, double branch) {
        if (n <= 0 || depth < 0) return null;
        final pts = [p], ds = [d], kids = <_Vein>[];
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
            final kid = walk(c, ca + side * (.5 + r.nextDouble()), cd,
                math.max(2, (n * (.3 + r.nextDouble() * .35)).floor()), depth - 1, branch * .7);
            if (kid != null) kids.add(kid);
          }
        }
        final v = _Vein(pts, ds, depth, system)..branches.addAll(kids);
        veins.add(v);
        if (cd > reachOf[system]) reachOf[system] = cd;
        return v;
      }

      walk(start, angle, 0, segs, 3, .45);
    }

    final w = s.width, h = s.height;
    // Nätet visas till [AmbientLife.rest] (82 %) — de sista 18 % är vad en
    // LOG sträcker ut det till innan det drar sig tillbaka.
    final roots = [
      (Offset(w + 6, -8), 2.35, 32, 1.15), // övre högra hörnet
      (Offset(-6, h + 8), -.78, 32, 1.15), // nedre vänstra hörnet
      (Offset(w + 4, h * .42), math.pi - .25, 21, 1.0), // höger kant
      (Offset(-4, h * .66), .2, 21, 1.0), // vänster kant
      (Offset(w * .7, h + 6), -1.9, 20, 1.0), // nederkant
      (Offset(w * .3, -6), 1.75, 17, .95), // överkant
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
  final _routes = <int, _Route>{};

  /// Pulsens väg i varv [lap] för system [i]: stammen från roten, och vid
  /// varje förgrening ett myntkast om den viker av ut i grenen (Niklas
  /// 2026-10-14: glöden ska inte ta samma rutt varje gång). Fröad per varv —
  /// ny väg varje varv, men samma bild för samma bildruta (golden-tester).
  _Route route(int i, int lap) {
    final cached = _routes[i];
    if (cached != null && cached.lap == lap) return cached;
    final r = math.Random(i * 7919 + lap);
    final legs = <({_Vein vein, double from, double to})>[];
    var cur = trunks[i];
    var from = cur.dist.first;
    turn:
    while (true) {
      for (final b in cur.branches) {
        if (b.dist.first <= from) continue;
        if (r.nextDouble() < .35) {
          legs.add((vein: cur, from: from, to: b.dist.first));
          cur = b;
          from = b.dist.first;
          continue turn;
        }
      }
      legs.add((vein: cur, from: from, to: cur.dist.last));
      break;
    }
    // Resten av varvet är paus — pulserna startar inte i takt.
    return _routes[i] = _Route(lap, legs, active: .55 + r.nextDouble() * .45);
  }

  /// Ådrorna så långt de vuxit vid [growth] — byggs om bara när nätet växer
  /// eller drar sig tillbaka (efter en LOG), inte i varje bildruta.
  List<Path?> grown(double growth) {
    if (growth != _grownAt) {
      _grown = [for (final v in veins) v.between(0, growth * reachOf[v.system])];
      _grownAt = growth;
    }
    return _grown;
  }

  double? _grownAt;
  List<Path?> _grown = const [];
}

/// En puls väg genom ett system: delsträckor på ådror, rot → spets.
class _Route {
  _Route(this.lap, this.legs, {required this.active})
      : length = legs.fold(0.0, (s, l) => s + l.to - l.from);
  final int lap;
  final List<({_Vein vein, double from, double to})> legs;
  final double length;

  /// Andel av varvet som pulsen rör sig.
  final double active;

  /// Bitarna av vägen mellan [a] och [b] (avstånd längs vägen), bara så
  /// långt nätet vuxit ([limit] = avstånd från roten).
  Iterable<Path> slice(double a, double b, double limit) sync* {
    var off = 0.0;
    for (final l in legs) {
      final len = l.to - l.from;
      final s = math.max(a, off), e = math.min(b, off + len);
      if (e > s) {
        final p = l.vein.between(l.from + s - off, math.min(l.from + e - off, limit));
        if (p != null) yield p;
      }
      off += len;
    }
  }
}

/// Ett nät per ytstorlek: kedjevyn (med menyraden) och passvyn är olika
/// höga, och under övergången ritas båda — med ett enda sparat nät byggdes
/// det om i varje bildruta.
final _nets = <Size, _Network>{};

/// Nätets hjärtslag: ett svagt lub-dub var 12:e sekund (360 steg à ~33 ms).
double _networkBeat(int frame) {
  final t = (frame % 360) / 40.0; // slaget tar ~1,3 s
  if (t > 1) return 0;
  double pulse(double c, double w) => math.exp(-math.pow((t - c) / w, 2).toDouble());
  return math.min(1.0, pulse(.15, .09) + .6 * pulse(.45, .09));
}

void paintVeins(Canvas canvas, Size size, int frame, ChainTheme theme, {required bool animated}) {
  if (size.isEmpty) return;
  var net = _nets[size];
  if (net == null) {
    if (_nets.length >= 4) _nets.clear(); // rotation, tangentbord: släpp gamla storlekar
    net = _nets[size] = _Network(size);
  }
  final beat = animated ? math.max(_networkBeat(frame), AmbientLife.beat()) : 0.0;
  final g = AmbientLife.growth(animated: animated);

  // Ådrorna, så långt de vuxit.
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final grown = net.grown(g);
  for (final (i, v) in net.veins.indexed) {
    final path = grown[i];
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

    // Pulser längs en ny väg varje varv, varannan inåt, varannan utåt. Bred,
    // mjuk glöd så att den lyser igenom glasets blur (Niklas 2026-10-14).
    final pulseGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..color = theme.hexEnergy.withValues(alpha: .6);
    final pulseCore = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = theme.hexEnergy.withValues(alpha: .9);
    const tail = 18.0;
    for (var i = 0; i < net.trunks.length; i++) {
      final p = net.pulses[i];
      final t = p.offset + frame * p.speed;
      final lap = t.floor();
      final route = net.route(i, lap);
      final f = (t - lap) / route.active;
      if (f >= 1) continue;
      final head = (i.isOdd ? 1 - f : f) * route.length;
      final segs = i.isOdd ? route.slice(head, head + tail, g * net.reachOf[i]) : route.slice(head - tail, head, g * net.reachOf[i]);
      for (final seg in segs) {
        canvas
          ..drawPath(seg, pulseGlow)
          ..drawPath(seg, pulseCore);
      }
    }

    // LOG: en ljusvåg från rötterna ut genom hela det vuxna nätet.
    for (final age in AmbientLife.burstAges) {
      final front = age / 1000 * 260; // px/s
      final fade = 1 - age / 3200; // vågen är kortare än utsträckningen
      if (fade <= 0) continue;
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
