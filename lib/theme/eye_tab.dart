/// Cosmic Horrors pågående pass (Niklas 2026-10-06, efter build 94): ögonen
/// tar hela markören, och kanten lever i stället för att glöda.
///
///   * [EyeVariant.slit] — en springa öppnar sig INNANFÖR fliken (2026-10-07):
///     texten delas och böjer sig efter mandeln, ett stort öga i springan
///     tittar runt, och den sluter sig igen. Fliken själv rör sig aldrig
///     utanför sina linjer.
///   * [EyeVariant.many] — ögon utspridda I flikens kant (kantlinjen delar sig
///     till ögonlock runt dem), som blinkar och tittar var för sig.
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

  /// Ögonlockens öppenhet ur blinkens klocka: stängs snabbt, öppnas lugnare.
  static double _lid(double t) => (t < .4 ? 1 - t / .4 : (t - .4) / .6).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final child = widget.child;
    return Stack(clipBehavior: Clip.none, children: [
      child,
      // Springan öppnar sig INNANFÖR fliken (Niklas 2026-10-07: "inte röra
      // sig utanför linjerna"): fliken står still, och ögonlocken + ögat
      // klipps till flikens kontur.
      if (widget.variant == EyeVariant.slit)
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _slit,
              builder: (context, _) {
                final lift = Curves.easeInOut.transform(_slit.value) * EyeTab.maxLift;
                if (lift <= .3) return const SizedBox.shrink();
                return ClipPath(
                  clipper: ShapeBorderClipper(shape: widget.shape),
                  child: LayoutBuilder(builder: (context, box) {
                    final slit = SlitGeometry(box.biggest, lift);
                    return Stack(children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _SlitPainter(slit: slit, membrane: widget.membrane, gaze: _gaze[0], theme: c)),
                      ),
                      // Ögonlocken: flikens två halvor, text och allt, i smala
                      // strimlor som var och en glider så långt mandeln är
                      // öppen just där (Niklas 2026-10-07: "texten ska formas
                      // efter ögats form") — mest i mitten, inget i vrårna.
                      for (final (x0, x1, d) in slit.strips)
                        for (final upper in const [true, false])
                          Positioned.fill(
                            child: Transform.translate(
                              offset: Offset(0, upper ? -d : d),
                              child: ClipRect(clipper: _Strip(x0, x1, upper: upper), child: child),
                            ),
                          ),
                      // Den fuktiga kanten ovanpå: döljer strimlornas trappsteg.
                      Positioned.fill(
                        child: CustomPaint(painter: _SlitRimPainter(slit: slit, theme: c)),
                      ),
                    ]);
                  }),
                );
              },
            ),
          ),
        ),
      // Kanten mullrar: konturen darrar svagt, ibland lite mer. Kantögonen
      // sitter I konturen — linjen delar sig till ögonlock runt dem.
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _EdgePainter(
                repaint: Listenable.merge([_life, ..._blinks]),
                shape: widget.shape,
                seconds: () => _life.isAnimating ? _life.value * 6 : null,
                eyes: widget.variant == EyeVariant.many
                    ? () => [for (var i = 0; i < _eyes; i++) (open: _lid(_blinks[i].value), gaze: _gaze[i])]
                    : null,
                color: widget.membrane.edge,
                theme: c,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// En lodrät strimla av ena halvan (övre eller nedre) av fliken.
class _Strip extends CustomClipper<Rect> {
  const _Strip(this.x0, this.x1, {required this.upper});
  final double x0, x1;
  final bool upper;

  @override
  Rect getClip(Size s) => upper ? Rect.fromLTRB(x0, 0, x1, s.height / 2) : Rect.fromLTRB(x0, s.height / 2, x1, s.height);

  @override
  bool shouldReclip(_Strip old) => old.x0 != x0 || old.x1 != x1 || old.upper != upper;
}

/// Springans mandel — EN geometri som både ögonlocken och öppningen följer.
/// Öppningen täcker 84 % av bredden; vid x är den [open] öppen åt vardera
/// håll: lift · 4u(1−u), dvs samma parabel som mandelns bezierkurvor.
class SlitGeometry {
  SlitGeometry(this.size, this.lift);
  final Size size;
  final double lift;

  static const stripCount = 40;

  double get width => size.width * .84;
  double get left => (size.width - width) / 2;
  double get cy => size.height / 2;

  double open(double x) {
    final u = (x - left) / width;
    return u <= 0 || u >= 1 ? 0 : lift * 4 * u * (1 - u);
  }

  /// (x0, x1, förskjutning) per strimla, mätt i strimlans mitt.
  Iterable<(double, double, double)> get strips sync* {
    final sw = width / stripCount;
    for (var i = 0; i < stripCount; i++) {
      final a = left + i * sw;
      yield (a, a + sw, open(a + sw / 2));
    }
  }

  Path get opening => Path()
    ..moveTo(left, cy)
    ..quadraticBezierTo(size.width / 2, cy - lift * 2, left + width, cy)
    ..quadraticBezierTo(size.width / 2, cy + lift * 2, left, cy)
    ..close();
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
  if (open < .08) {
    canvas.drawLine(Offset(c.dx - w / 2, c.dy), Offset(c.dx + w / 2, c.dy), Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = t.accent.withValues(alpha: .7));
    return;
  }
  _eyeGlow(canvas, t, almond, h);
  canvas.save();
  canvas.clipPath(almond);
  _eyeball(canvas, t, c, w, h, gaze);
  canvas.restore();
  canvas.drawPath(almond, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = .9
    ..color = t.accent.withValues(alpha: .8));
}

Color _iris(ChainTheme t) => Color.lerp(t.success, t.restGold, .45)!; // sjuk gulgrön

void _eyeGlow(Canvas canvas, ChainTheme t, Path almond, double h) => canvas.drawPath(almond, Paint()
  ..color = _iris(t).withValues(alpha: .35)
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.5, h * .25)));

/// Ögongloben kring [c], liggande längs x — anroparen klipper till mandeln.
void _eyeball(Canvas canvas, ChainTheme t, Offset c, double w, double h, double gaze) {
  final iris = _iris(t);
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
}

/// Springan mellan ögonlocken: den mandelformade öppningen med ett stort öga
/// som tittar runt. Bakom locken flikens egen färg, där strimlorna glipar.
class _SlitPainter extends CustomPainter {
  _SlitPainter({required this.slit, required this.membrane, required this.gaze, required this.theme});
  final SlitGeometry slit;
  final RaisedMaterial membrane;
  final double gaze;
  final ChainTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme, cy = slit.cy, lift = slit.lift;
    canvas.drawRect(
      Rect.fromLTRB(slit.left, cy - lift - 1, slit.left + slit.width, cy + lift + 1),
      Paint()..color = Color.lerp(membrane.top, membrane.bottom, .5)!,
    );
    canvas.drawPath(slit.opening, Paint()..color = Color.lerp(t.fail, t.background, .8)!);
    drawEye(canvas, t, Offset(size.width / 2, cy), slit.width * .92, lift * 2 * .9, 1, gaze);
  }

  @override
  bool shouldRepaint(_SlitPainter old) => true;
}

/// Fuktig kant runt springans öppning — ovanpå ögonlocken.
class _SlitRimPainter extends CustomPainter {
  _SlitRimPainter({required this.slit, required this.theme});
  final SlitGeometry slit;
  final ChainTheme theme;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(slit.opening, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3
    ..color = theme.accent.withValues(alpha: .7));

  @override
  bool shouldRepaint(_SlitRimPainter old) => true;
}

/// Flikens kant, och kantögonen I den.
///
/// Kanten mullrar (Niklas 2026-10-07: "linjerna skulle bara typ kunna
/// vibrera, lite som något mullrande under ytan"): konturen darrar svagt hela
/// tiden och ibland lite kraftigare, som en stöt underifrån. Max ~1,5 px.
/// Stilla ([seconds] ger null) = lugn kontur.
///
/// Kantögonen (Niklas 2026-10-07: kanterna "följer inte dem"): konturen delar
/// sig vid varje öga till två ögonlock som böjer sig längs kanten och möts
/// igen. Ett slutet öga är bara kantlinjen. Ögongloben vrids efter kanten.
class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required Listenable repaint,
    required this.shape,
    required this.seconds,
    required this.eyes,
    required this.color,
    required this.theme,
  }) : super(repaint: repaint);
  final ShapeBorder shape;
  final double? Function() seconds;

  /// Kantögonens läge just nu; null = inga kantögon (springan).
  final List<({double open, double gaze})> Function()? eyes;
  final Color color;
  final ChainTheme theme;

  /// (andel av konturen, bredd, höjd)
  static const _spots = [(.05, 15.0, 8.5), (.27, 20.0, 11.0), (.43, 12.0, 7.0), (.6, 18.0, 10.0), (.83, 13.0, 7.5)];

  /// Mullrets styrka 0–1: ett lågt grundmuller och glesa stötar.
  static double rumble(double s) {
    double surge(double v) => math.pow(.5 + .5 * math.sin(v), 10).toDouble();
    return math.min(1.0, .25 + surge(s * 1.05) + .7 * surge(s * .41 + 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final metric = shape.getOuterPath(Offset.zero & size).computeMetrics().first;
    final len = metric.length;
    final s = seconds();
    final amp = s == null ? 0.0 : 1.5 * rumble(s);
    final state = eyes?.call() ?? const [];
    final spans = [
      for (final (i, (at, w, h)) in _spots.indexed)
        if (i < state.length) (from: len * at - w / 2, w: w, h: h, lid: state[i].open < .08 ? 0.0 : h / 2 * state[i].open, gaze: state[i].gaze),
    ];

    // Hur långt ögonlocken buktar ut från kanten vid avståndet d.
    double bulge(double d) {
      for (final e in spans) {
        final u = (d - e.from) / e.w;
        if (u > 0 && u < 1) return e.lid * 4 * u * (1 - u);
      }
      return 0;
    }

    Offset at(double d, double lift) {
      final tan = metric.getTangentForOffset(d.clamp(0.0, len))!;
      final n = Offset(-tan.vector.dy, tan.vector.dx);
      final j = s == null ? 0.0 : (math.sin(d * .9 + s * 47) * .6 + math.sin(d * .31 - s * 29) * .4) * amp;
      return tan.position + n * (j + lift);
    }

    Iterable<double> samples(double from, double to, double step) sync* {
      for (var d = from; d < to; d += step) {
        yield d;
      }
      yield to;
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    // Ögonen först (glöd + glob), sedan kantlinjen ovanpå.
    final lower = Path();
    for (final e in spans) {
      if (e.lid <= 0) continue;
      final ds = samples(e.from, e.from + e.w, 1).toList();
      final almond = Path()..addPolygon([for (final d in ds) at(d, -bulge(d)), for (final d in ds.reversed) at(d, bulge(d))], true);
      final mid = e.from + e.w / 2;
      final tan = metric.getTangentForOffset(mid.clamp(0.0, len))!;
      _eyeGlow(canvas, theme, almond, e.h);
      canvas.save();
      canvas.clipPath(almond);
      canvas.translate(at(mid, 0).dx, at(mid, 0).dy);
      canvas.rotate(math.atan2(tan.vector.dy, tan.vector.dx));
      _eyeball(canvas, theme, Offset.zero, e.w, e.h, e.gaze);
      canvas.restore();
      lower.addPolygon([for (final d in ds) at(d, bulge(d))], false);
    }

    // Kantlinjen = övre ögonlocken; finare steg där den buktar runt ett öga.
    final edge = Path();
    var first = true;
    for (var d = 0.0; d < len; d += bulge(d) > 0 || bulge(d + 3) > 0 ? 1 : 3) {
      final p = at(d, -bulge(d));
      first ? edge.moveTo(p.dx, p.dy) : edge.lineTo(p.dx, p.dy);
      first = false;
    }
    edge.close();
    canvas
      ..drawPath(edge, stroke)
      ..drawPath(lower, stroke);
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}
