/// Nanosuits rörliga hex-väv, portad från MK1 (_startNanosuitHex i index.html):
/// en dämpad statisk väv + energivågor (ringar och svep) som tänder hexagonerna.
/// ~30 fps-tak. Av-läge (ambient av eller systemets "minska rörelse") ritar
/// bara den statiska väven — bakgrunden blir aldrig tom.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class _Wave {
  _Wave.ring(this.x, this.y, this.maxR, this.speed, this.width, this.strength)
      : isRing = true,
        dx = 0,
        dy = 0,
        end = 0;
  _Wave.sweep(this.dx, this.dy, this.pos, this.end, this.speed, this.width, this.strength)
      : isRing = false,
        x = 0,
        y = 0,
        maxR = 0;

  final bool isRing;
  double x, y, maxR, dx, dy, end;
  double r = 0;
  double pos = 0;
  final double speed, width, strength;
}

class HexFieldModel extends ChangeNotifier {
  HexFieldModel({math.Random? random}) : _rnd = random ?? math.Random();

  static const size = 16.0, idleAmp = 0.09, intensity = 0.92;
  static const ringEvery = 80, sweepEvery = 260;

  final math.Random _rnd;
  final waves = <_Wave>[];
  Size _area = Size.zero;
  List<Offset> hexes = const [];
  List<double> phase = const [];
  int frame = 0;

  void layout(Size area) {
    if (area == _area) return;
    _area = area;
    final hh = math.sqrt(3) * size, colX = size * 1.5;
    final cols = (area.width / colX).ceil() + 2, rows = (area.height / hh).ceil() + 2;
    final pts = <Offset>[], ph = <double>[];
    for (var cx = -1; cx < cols; cx++) {
      for (var cy = -1; cy < rows; cy++) {
        final x = cx * colX, y = cy * hh + (cx.isOdd ? hh / 2 : 0);
        pts.add(Offset(x, y));
        ph.add(x * 0.012 + y * 0.009);
      }
    }
    hexes = pts;
    phase = ph;
  }

  void _ring() {
    final w = _area.width, h = _area.height;
    waves.add(_Wave.ring(_rnd.nextDouble() * w, _rnd.nextDouble() * h,
        math.sqrt(w * w + h * h) * (0.45 + _rnd.nextDouble() * 0.35), 1.4 + _rnd.nextDouble() * 1.4,
        26 + _rnd.nextDouble() * 22, 0.7 + _rnd.nextDouble() * 0.5));
  }

  void _sweep() {
    final w = _area.width, h = _area.height;
    final ang = (_rnd.nextBool() ? 1 : -1) * (0.5 + _rnd.nextDouble() * 0.6);
    final dx = math.cos(ang), dy = math.sin(ang);
    var lo = double.infinity, hi = -double.infinity;
    for (final c in [Offset.zero, Offset(w, 0), Offset(0, h), Offset(w, h)]) {
      final p = c.dx * dx + c.dy * dy;
      lo = math.min(lo, p);
      hi = math.max(hi, p);
    }
    waves.add(_Wave.sweep(dx, dy, lo - 60, hi + 60, 2.6 + _rnd.nextDouble() * 1.8,
        40 + _rnd.nextDouble() * 26, 0.55 + _rnd.nextDouble() * 0.4)
      ..pos = lo - 60);
  }

  /// Ett steg i ~30 fps-takt.
  void step() {
    if (_area.isEmpty) return;
    frame++;
    if (waves.isEmpty && frame == 1) {
      _ring();
      _sweep();
    }
    if (frame % ringEvery == 0) _ring();
    if (frame % sweepEvery == 0) _sweep();
    for (var i = waves.length - 1; i >= 0; i--) {
      final w = waves[i];
      if (w.isRing) {
        w.r += w.speed;
        if (w.r > w.maxR) waves.removeAt(i);
      } else {
        w.pos += w.speed;
        if (w.pos > w.end) waves.removeAt(i);
      }
    }
    notifyListeners();
  }

  double energyAt(Offset p) {
    var e = 0.0;
    for (final w in waves) {
      if (w.isRing) {
        final d = (p - Offset(w.x, w.y)).distance;
        final fade = 1 - w.r / w.maxR;
        e += math.exp(-((d - w.r) * (d - w.r)) / (2 * w.width * w.width)) * w.strength * fade;
      } else {
        final d = (p.dx * w.dx + p.dy * w.dy) - w.pos;
        e += math.exp(-(d * d) / (2 * w.width * w.width)) * w.strength;
      }
    }
    return e;
  }
}

Path _hex(Offset c, double r) {
  final p = Path();
  for (var i = 0; i < 6; i++) {
    final a = math.pi / 180 * (60 * i);
    final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

class HexFieldPainter extends CustomPainter {
  HexFieldPainter(this.model, {required this.line, required this.animated}) : super(repaint: model);

  final HexFieldModel model;
  final Color line;
  final bool animated;

  @override
  void paint(Canvas canvas, Size size) {
    model.layout(size);
    const r = HexFieldModel.size - 1.2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = line;
    final weave = Path();
    for (final h in model.hexes) {
      weave.addPath(_hex(h, r), Offset.zero);
    }
    canvas.drawPath(weave, base);
    if (!animated) return;

    final fill = Paint()..blendMode = BlendMode.plus;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..blendMode = BlendMode.plus;
    final t = model.frame;
    for (var i = 0; i < model.hexes.length; i++) {
      final h = model.hexes[i];
      final idle = HexFieldModel.idleAmp * (0.5 + 0.5 * math.sin(t * 0.018 - model.phase[i] * 6));
      var e = model.energyAt(h) * HexFieldModel.intensity + idle;
      if (e < 0.06) continue;
      if (e > 1.25) e = 1.25;
      final k = math.min(1.0, e);
      final path = _hex(h, r);
      fill.color = Color.fromARGB(
          (math.min(0.6, e * 0.42) * 255).round(), (174 * k * k).round(), math.min(255, (212 + 43 * k).round()), 255);
      canvas.drawPath(path, fill);
      if (e > 0.6) {
        stroke.color = Color.fromARGB(
            (math.min(0.9, e * 0.55) * 255).round(), (160 + 60 * k).round(), 255, 255);
        canvas.drawPath(path, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(HexFieldPainter old) => old.animated != animated || old.line != line;
}

/// Bakgrundslagret. [enabled] = användarens ambient-inställning; systemets
/// "minska rörelse" stänger också av animationen.
class HexFieldBackground extends StatefulWidget {
  const HexFieldBackground({super.key, required this.line, this.enabled = true});

  final Color line;
  final bool enabled;

  @override
  State<HexFieldBackground> createState() => _HexFieldBackgroundState();
}

class _HexFieldBackgroundState extends State<HexFieldBackground> with SingleTickerProviderStateMixin {
  final _model = HexFieldModel();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  bool get _animate => widget.enabled && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _onTick(Duration now) {
    if (now - _last < const Duration(milliseconds: 33)) return; // ~30 fps
    _last = now;
    _model.step();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(HexFieldBackground old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_animate && !_ticker.isActive) _ticker.start();
    if (!_animate && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: HexFieldPainter(_model, line: widget.line, animated: _animate),
          size: Size.infinite,
        ),
      );
}
