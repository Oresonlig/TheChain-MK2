/// Cosmic Horrors pågående pass (Niklas 2026-10-06, efter build 94): ögonen
/// tar hela markören, och kanten lever i stället för att glöda.
///
///   * [EyeVariant.slit] — en springa öppnar sig INNANFÖR fliken (2026-10-07):
///     texten delas, ett stort öga i springan tittar runt, och den sluter sig
///     igen. Fliken själv rör sig aldrig utanför sina linjer.
///   * [EyeVariant.many] — ögon utspridda runt flikens kant, grensle över den,
///     som blinkar och tittar var för sig.
///   * Kanten (båda): konturen darrar, som något som mullrar under ytan.
///     Syns alltid, så markeringen finns kvar även när springan är sluten.
///     Ingen grön prick.
///
/// Varianten slumpas 50/50 per appstart ([EyeChoice]); DEV-knappen växlar.
/// Stilla (minska rörelse / ambient av): springan halvöppen, ögonen öppna.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chain_theme.dart';

/// Nästa blinkning: 2,5–9 s bort, aldrig i takt (Niklas 2026-10-06: "inte
/// alltid var 3:e sekund"). Ibland en dubbelblinkning direkt efter.
Duration nextBlink(math.Random r) => Duration(milliseconds: 2500 + r.nextInt(6500));

enum EyeVariant { many, slit }

/// Slumpas 50/50 en gång per appstart (byter aldrig mitt i ett pass).
class EyeChoice {
  EyeChoice._();
  static EyeVariant current = math.Random().nextBool() ? EyeVariant.many : EyeVariant.slit;
  static void toggle() => current = current == EyeVariant.many ? EyeVariant.slit : EyeVariant.many;
}

/// Plats som behövs utanför fliken (kantögonen, darret) — kedjeremsan
/// lägger den innanför sin scroll, annars klipps de vid flikens kant.
const eyeTabRoom = 8.0;

class EyeTab extends StatefulWidget {
  const EyeTab({
    super.key,
    required this.variant,
    required this.shape,
    required this.membrane,
    required this.child,
    this.animate = true,
    this.random,
  });

  final EyeVariant variant;

  /// Flikens form (samma som [Raised] ritar) — kantögonen och ådrorna följer den.
  final ShapeBorder shape;

  /// Flikens yta — springans sträckta membran får samma färg.
  final RaisedMaterial membrane;
  final Widget child;
  final bool animate;
  final math.Random? random;

  /// Hur långt halvorna glider isär (var för sig) — inom flikens höjd.
  static const maxLift = 11.0;

  @override
  State<EyeTab> createState() => _EyeTabState();
}

class _EyeTabState extends State<EyeTab> with TickerProviderStateMixin {
  late final math.Random _r = widget.random ?? math.Random();
  static const _eyes = 5;

  /// Klocka för darret (6 s per varv).
  late final AnimationController _life = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  late final List<AnimationController> _blinks = [
    for (var i = 0; i < _eyes; i++) AnimationController(vsync: this, duration: const Duration(milliseconds: 220)),
  ];
  late final AnimationController _slit = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
  final _gaze = List<double>.filled(_eyes, 0);
  int _gen = 0;
  final _timers = <Timer>{};

  bool get _moving => widget.animate && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  @override
  void didUpdateWidget(EyeTab old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate || old.variant != widget.variant) _restart();
  }

  void _restart() {
    _cancelWaits();
    final gen = ++_gen;
    for (final b in _blinks) {
      b.value = 0;
    }
    _gaze.fillRange(0, _eyes, 0);
    if (!_moving) {
      _life.stop();
      _slit.value = .6; // stilla: springan halvöppen, ögat syns
      return;
    }
    if (!_life.isAnimating) _life.repeat();
    if (widget.variant == EyeVariant.many) {
      for (var i = 0; i < _eyes; i++) {
        _blinkLoop(i, gen);
      }
    } else {
      _slit.value = 0;
      _slitLoop(gen);
    }
  }

  bool _alive(int gen) => mounted && gen == _gen && _moving;

  /// Väntan som avbryts vid omstart/dispose (inga hängande timers).
  Future<void> _wait(Duration d) {
    final done = Completer<void>();
    late final Timer t;
    t = Timer(d, () {
      _timers.remove(t);
      done.complete();
    });
    _timers.add(t);
    return done.future;
  }

  void _cancelWaits() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  Future<void> _blinkLoop(int i, int gen) async {
    while (true) {
      await _wait(nextBlink(_r));
      if (!_alive(gen)) return;
      await _blinks[i].forward(from: 0);
      if (!_alive(gen)) return;
      _blinks[i].value = 0;
      setState(() => _gaze[i] = _r.nextDouble() < .4 ? 0 : _r.nextDouble() * 2 - 1);
      if (_r.nextDouble() < .2) {
        await _blinks[i].forward(from: 0); // dubbelblink
        if (!_alive(gen)) return;
        _blinks[i].value = 0;
      }
    }
  }

  Future<void> _slitLoop(int gen) async {
    while (true) {
      await _wait(Duration(milliseconds: 1800 + _r.nextInt(3500))); // sluten
      if (!_alive(gen)) return;
      await _slit.forward();
      if (!_alive(gen)) return;
      for (var k = 0, n = 2 + _r.nextInt(3); k < n; k++) {
        await _wait(Duration(milliseconds: 600 + _r.nextInt(900)));
        if (!_alive(gen)) return;
        setState(() => _gaze[0] = _r.nextDouble() * 2 - 1); // tittar runt
      }
      await _wait(Duration(milliseconds: 500 + _r.nextInt(700)));
      if (!_alive(gen)) return;
      setState(() => _gaze[0] = 0);
      await _slit.reverse();
      if (!_alive(gen)) return;
    }
  }

  @override
  void dispose() {
    _gen++;
    _cancelWaits();
    _life.dispose();
    for (final b in _blinks) {
      b.dispose();
    }
    _slit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final child = widget.child;
    return AnimatedBuilder(
      animation: Listenable.merge([_life, _slit, ..._blinks]),
      builder: (context, _) {
        final lift = widget.variant == EyeVariant.slit ? Curves.easeInOut.transform(_slit.value) * EyeTab.maxLift : 0.0;
        double lid(double t) => (t < .4 ? 1 - t / .4 : (t - .4) / .6).clamp(0.0, 1.0);
        return Stack(clipBehavior: Clip.none, children: [
          child,
          // Springan öppnar sig INNANFÖR fliken (Niklas 2026-10-07: "inte röra
          // sig utanför linjerna"): fliken står still, och halvorna + ögat
          // klipps till flikens kontur.
          if (lift > .3)
            Positioned.fill(
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: widget.shape),
                child: Stack(children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SlitPainter(shape: widget.shape, membrane: widget.membrane, lift: lift, gaze: _gaze[0], theme: c),
                    ),
                  ),
                  // Ögonlocken: flikens två halvor, text och allt.
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(0, -lift),
                      child: ClipRect(clipper: const _Half(upper: true), child: child),
                    ),
                  ),
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(0, lift),
                      child: ClipRect(clipper: const _Half(upper: false), child: child),
                    ),
                  ),
                ]),
              ),
            ),
          // Kanten mullrar: konturen darrar svagt, ibland lite mer.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TremorPainter(
                  shape: widget.shape,
                  seconds: _life.isAnimating ? _life.value * 6 : null,
                  color: widget.membrane.edge,
                ),
              ),
            ),
          ),
          if (widget.variant == EyeVariant.many)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _RimEyesPainter(
                    shape: widget.shape,
                    open: [for (final b in _blinks) lid(b.value)],
                    gaze: List.of(_gaze),
                    theme: c,
                  ),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

class _Half extends CustomClipper<Rect> {
  const _Half({required this.upper});
  final bool upper;

  @override
  Rect getClip(Size s) => upper ? Rect.fromLTWH(0, 0, s.width, s.height / 2) : Rect.fromLTWH(0, s.height / 2, s.width, s.height / 2);

  @override
  bool shouldReclip(_Half old) => old.upper != upper;
}

/// Ett öga: mandel, mörkt sjukt vitöga med blodkärl, gulgrön iris och en
/// smal lodrät pupill — reptil, inte groda. [open] 0 = stängt, 1 = öppet.
void drawEye(Canvas canvas, ChainTheme t, Offset c, double w, double h, double open, double gaze) {
  final lid = h / 2 * open;
  final almond = Path()
    ..moveTo(c.dx - w / 2, c.dy)
    ..quadraticBezierTo(c.dx, c.dy - lid * 2, c.dx + w / 2, c.dy)
    ..quadraticBezierTo(c.dx, c.dy + lid * 2, c.dx - w / 2, c.dy)
    ..close();
  final iris = Color.lerp(t.success, t.restGold, .45)!; // sjuk gulgrön
  if (open < .08) {
    canvas.drawLine(Offset(c.dx - w / 2, c.dy), Offset(c.dx + w / 2, c.dy), Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = t.accent.withValues(alpha: .7));
    return;
  }
  canvas.drawPath(almond, Paint()
    ..color = iris.withValues(alpha: .35)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.5, h * .25)));
  canvas.save();
  canvas.clipPath(almond);
  final box = Rect.fromCenter(center: c, width: w, height: h);
  canvas.drawRect(
    box,
    Paint()..shader = const RadialGradient(colors: [Color(0xFF3A4A30), Color(0xFF101810)]).createShader(box),
  );
  final vessel = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(.5, h * .06)
    ..color = t.fail.withValues(alpha: .6);
  for (final s in const [-1.0, 1.0]) {
    final corner = Offset(c.dx + s * w * .46, c.dy);
    canvas
      ..drawLine(corner, corner + Offset(-s * w * .18, -h * .2), vessel)
      ..drawLine(corner, corner + Offset(-s * w * .14, h * .22), vessel);
  }
  final ic = c + Offset(gaze * w * .22, 0);
  final ir = math.min(h * .44, w * .2);
  canvas.drawCircle(
    ic,
    ir,
    Paint()
      ..shader = RadialGradient(colors: [
        Color.lerp(iris, Colors.white, .3)!,
        iris,
        Color.lerp(iris, t.background, .6)!,
      ], stops: const [0, .5, 1]).createShader(Rect.fromCircle(center: ic, radius: ir)),
  );
  canvas.drawOval(Rect.fromCenter(center: ic, width: math.max(1.4, ir * .32), height: ir * 1.85), Paint()..color = t.background);
  canvas.drawCircle(ic + Offset(-ir * .4, -ir * .45), math.max(.8, ir * .14), Paint()..color = Colors.white.withValues(alpha: .5));
  canvas.restore();
  canvas.drawPath(almond, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = .9
    ..color = t.accent.withValues(alpha: .8));
}

/// Springan mellan ögonlocken. Membranet sträcks i flikens egen färg, så att
/// bara den mandelformade öppningen syns — med ett stort öga som tittar runt.
class _SlitPainter extends CustomPainter {
  _SlitPainter({required this.shape, required this.membrane, required this.lift, required this.gaze, required this.theme});
  final ShapeBorder shape;
  final RaisedMaterial membrane;
  final double lift, gaze;
  final ChainTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    final w = size.width, cy = size.height / 2;
    final gap = Rect.fromLTRB(0, cy - lift, w, cy + lift);
    // Det sträckta membranet — bara inom flikens kontur.
    canvas.save();
    canvas.clipPath(shape.getOuterPath(Offset.zero & size));
    canvas.drawRect(gap.inflate(1), Paint()..color = Color.lerp(membrane.top, membrane.bottom, .5)!);
    canvas.restore();
    // Öppningen: en mandel som vidgas med ögonlocken.
    final ow = w * .84, oh = lift * 2;
    final opening = Path()
      ..moveTo(w / 2 - ow / 2, cy)
      ..quadraticBezierTo(w / 2, cy - oh, w / 2 + ow / 2, cy)
      ..quadraticBezierTo(w / 2, cy + oh, w / 2 - ow / 2, cy)
      ..close();
    canvas.drawPath(opening, Paint()..color = Color.lerp(t.fail, t.background, .8)!);
    drawEye(canvas, t, Offset(w / 2, cy), ow * .92, oh * .9, 1, gaze);
    // Fuktig kant runt öppningen.
    canvas.drawPath(opening, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = t.accent.withValues(alpha: .7));
  }

  @override
  bool shouldRepaint(_SlitPainter old) => true;
}

/// Ögon grensle över flikens kant, utspridda runt den.
class _RimEyesPainter extends CustomPainter {
  _RimEyesPainter({required this.shape, required this.open, required this.gaze, required this.theme});
  final ShapeBorder shape;
  final List<double> open, gaze;
  final ChainTheme theme;

  /// (andel av konturen, bredd, höjd)
  static const _spots = [(.05, 15.0, 8.5), (.27, 20.0, 11.0), (.43, 12.0, 7.0), (.6, 18.0, 10.0), (.83, 13.0, 7.5)];

  @override
  void paint(Canvas canvas, Size size) {
    final metric = shape.getOuterPath(Offset.zero & size).computeMetrics().first;
    for (final (i, (at, w, h)) in _spots.indexed) {
      final p = metric.getTangentForOffset(metric.length * at)?.position;
      if (p == null) continue;
      drawEye(canvas, theme, p, w, h, open[i], gaze[i]);
    }
  }

  @override
  bool shouldRepaint(_RimEyesPainter old) => true;
}

/// Kanten mullrar (Niklas 2026-10-07: "linjerna skulle bara typ kunna
/// vibrera, lite som något mullrande under ytan"): flikens kontur darrar
/// svagt hela tiden och ibland lite kraftigare, som en stöt underifrån.
/// Max ~1,5 px — inget som tar över. Stilla ([seconds] null) = lugn kontur.
class _TremorPainter extends CustomPainter {
  _TremorPainter({required this.shape, required this.seconds, required this.color});
  final ShapeBorder shape;
  final double? seconds;
  final Color color;

  /// Mullrets styrka 0–1: ett lågt grundmuller och glesa stötar.
  static double rumble(double s) {
    double surge(double v) => math.pow(.5 + .5 * math.sin(v), 10).toDouble();
    return math.min(1.0, .25 + surge(s * 1.05) + .7 * surge(s * .41 + 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = shape.getOuterPath(Offset.zero & size);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final s = seconds;
    if (s == null) {
      canvas.drawPath(path, paint);
      return;
    }
    final amp = 1.5 * rumble(s);
    final metric = path.computeMetrics().first;
    final shaky = Path();
    for (var d = 0.0; d <= metric.length; d += 3) {
      final tan = metric.getTangentForOffset(d);
      if (tan == null) continue;
      final n = Offset(-tan.vector.dy, tan.vector.dx);
      final j = (math.sin(d * .9 + s * 47) * .6 + math.sin(d * .31 - s * 29) * .4) * amp;
      final p = tan.position + n * j;
      d == 0 ? shaky.moveTo(p.dx, p.dy) : shaky.lineTo(p.dx, p.dy);
    }
    shaky.close();
    canvas.drawPath(shaky, paint);
  }

  @override
  bool shouldRepaint(_TremorPainter old) => old.seconds != seconds || old.color != color;
}
