/// Pågående pass i kedjan: temats [ActiveMark] runt fliken (pricken står kvar).
/// Nanosuit (Niklas 2026-10-03): ett kort blått ljusspår som löper runt
/// chevron-konturen — sticker ut men tar inte över. Cosmic Horror: hela
/// fliken blir ett öga ([Eye]). Rörlig bakgrund av
/// eller systemets "minska rörelse" → stillastående kant / öppet öga.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'chain_theme.dart';
import 'surfaces.dart';

class ActiveMarkFrame extends StatefulWidget {
  const ActiveMarkFrame({
    super.key,
    required this.active,
    required this.child,
    this.animate = true,
    this.inset = 8,
  });

  /// Passet pågår.
  final bool active;
  final Widget child;

  /// Användarens ambient-inställning.
  final bool animate;

  /// Samma avfasning som [Raised] runt barnet.
  final double inset;

  @override
  State<ActiveMarkFrame> createState() => _ActiveMarkFrameState();
}

class _ActiveMarkFrameState extends State<ActiveMarkFrame> with SingleTickerProviderStateMixin {
  /// Ett varv: lugnt nog att märkas i ögonvrån utan att dra blicken.
  static const lap = Duration(milliseconds: 4000);
  late final AnimationController _ctl = AnimationController(vsync: this, duration: lap);

  bool _moving(ActiveMark mark) =>
      widget.active &&
      mark == ActiveMark.tracePulse &&
      widget.animate &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _sync() {
    if (_moving(context.chain.activeMark)) {
      if (!_ctl.isAnimating) _ctl.repeat();
    } else if (_ctl.isAnimating) {
      _ctl.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ActiveMarkFrame old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    if (!widget.active || c.activeMark == ActiveMark.none) return widget.child;
    // Ögat ersätter hela fliken ([Eye]) — ingen ram här.
    if (c.activeMark == ActiveMark.eye) return widget.child;
    final moving = _moving(c.activeMark);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctl,
        child: widget.child,
        builder: (context, child) => CustomPaint(
          foregroundPainter: _TracePainter(
            color: c.accentBright,
            inset: widget.inset,
            head: moving ? _ctl.value : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Nästa blinkning: 2,5–9 s bort, aldrig i takt (Niklas 2026-10-06: "inte
/// alltid var 3:e sekund"). Ibland en dubbelblinkning direkt efter.
Duration nextBlink(math.Random r) => Duration(milliseconds: 2500 + r.nextInt(6500));

/// Cosmic Horrors två ögonvarianter (Niklas 2026-10-06: helflik-ögat blev ett
/// grodöga — "både 2 och 3, slumpmässigt vilket man får när man startar").
/// Fliken är en vanlig blob med bokstav och namn; ögonen sitter i flikens
/// slut, där den gröna pricken annars står. Smala pupiller, sjuk färg.
enum EyeVariant {
  /// Tre ögon i olika storlek som blinkar och tittar var för sig.
  many,

  /// En springa i membranet som öppnar sig ibland; ett öga tittar runt och
  /// sluter sig igen.
  slit,
}

/// Slumpas 50/50 en gång per appstart (byter aldrig mitt i ett pass).
/// DEV-knappen i kedjevyn växlar.
class EyeChoice {
  EyeChoice._();
  static EyeVariant current = math.Random().nextBool() ? EyeVariant.many : EyeVariant.slit;
  static void toggle() => current = current == EyeVariant.many ? EyeVariant.slit : EyeVariant.many;
}

/// Det pågående passets markering i Cosmic Horror. Ge en ny [key] per
/// variant (ValueKey) så börjar animationen om när DEV-knappen växlar.
/// Stilla (minska rörelse / ambient av) = ögonen öppna, rakt fram.
class EyeMark extends StatefulWidget {
  const EyeMark({super.key, required this.variant, this.animate = true, this.random});
  final EyeVariant variant;
  final bool animate;
  final math.Random? random;

  /// Ritas i en 40×30-ruta och skalas upp hit (ryms i flikens höjd).
  static const size = Size(44, 33);

  @override
  State<EyeMark> createState() => _EyeMarkState();
}

class _EyeMarkState extends State<EyeMark> with TickerProviderStateMixin {
  late final math.Random _r = widget.random ?? math.Random();

  /// Ett lock per öga: 0 = öppet, 1 = stängt (en blinkning = 0 → 1 → 0).
  late final List<AnimationController> _blinks = [
    for (var i = 0; i < 3; i++) AnimationController(vsync: this, duration: const Duration(milliseconds: 220)),
  ];

  /// Springans öppning: 0 = sluten söm, 1 = öppen.
  late final AnimationController _slit = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  final _gaze = [0.0, 0.0, 0.0];
  int _gen = 0; // avbryter gamla slingor

  bool get _moving => widget.animate && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  @override
  void didUpdateWidget(EyeMark old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate || old.variant != widget.variant) _restart();
  }

  void _restart() {
    _cancelWaits();
    final gen = ++_gen;
    for (final b in _blinks) {
      b.value = 0;
    }
    _gaze.fillRange(0, 3, 0);
    if (!_moving) {
      _slit.value = 1; // stilla: ögat syns
      return;
    }
    if (widget.variant == EyeVariant.many) {
      for (var i = 0; i < 3; i++) {
        _blinkLoop(i, gen);
      }
    } else {
      _slit.value = 0;
      _slitLoop(gen);
    }
  }

  bool _alive(int gen) => mounted && gen == _gen && _moving;

  /// Väntan som avbryts vid omstart/dispose (inga hängande timers).
  final _timers = <Timer>{};
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
    for (final b in _blinks) {
      b.dispose();
    }
    _slit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    return AnimatedBuilder(
      animation: Listenable.merge([..._blinks, _slit]),
      builder: (context, _) {
        // En blinkning: stäng snabbt, öppna lite långsammare.
        double lid(double t) => (t < .4 ? 1 - t / .4 : (t - .4) / .6).clamp(0.0, 1.0);
        return CustomPaint(
          size: EyeMark.size,
          painter: _EyeMarkPainter(
            variant: widget.variant,
            open: [
              for (final b in _blinks) lid(b.value),
            ],
            slit: Curves.easeInOut.transform(_slit.value),
            gaze: List.of(_gaze),
            theme: c,
          ),
        );
      },
    );
  }
}

class _EyeMarkPainter extends CustomPainter {
  _EyeMarkPainter({required this.variant, required this.open, required this.slit, required this.gaze, required this.theme});
  final EyeVariant variant;
  final List<double> open;
  final double slit;
  final List<double> gaze;
  final ChainTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 40);
    switch (variant) {
      case EyeVariant.many:
        // Tre ögon som växt fram ur membranet, ett stort och två små.
        _eye(canvas, const Offset(25, 15), 24, 13, open[0], gaze[0]);
        _eye(canvas, const Offset(8, 7), 12, 7, open[1], gaze[1]);
        _eye(canvas, const Offset(10, 24), 11, 6, open[2], gaze[2]);
      case EyeVariant.slit:
        // Sömmen syns alltid — markeringen försvinner aldrig helt.
        final seam = Path()
          ..moveTo(1, 15)
          ..quadraticBezierTo(20, 12.5, 39, 15);
        canvas.drawPath(seam, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = theme.success.withValues(alpha: .25 + .25 * (1 - slit))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        canvas.drawPath(seam, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(theme.background, theme.success, .55)!);
        if (slit > .02) _eye(canvas, const Offset(20, 14.5), 38, 22, slit, gaze[0]);
    }
  }

  /// Ett öga: mandel, mörkt sjukt vitöga med blodkärl, gulgrön iris och en
  /// smal lodrät pupill. [open] 0 = stängt, 1 = öppet.
  void _eye(Canvas canvas, Offset c, double w, double h, double open, double gaze) {
    final t = theme;
    final lid = h / 2 * open;
    final almond = Path()
      ..moveTo(c.dx - w / 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy - lid * 2, c.dx + w / 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + lid * 2, c.dx - w / 2, c.dy)
      ..close();
    final iris = Color.lerp(t.success, t.restGold, .45)!; // sjuk gulgrön
    if (open < .08) {
      // Stängt: bara lockets linje.
      canvas.drawLine(Offset(c.dx - w / 2, c.dy), Offset(c.dx + w / 2, c.dy), Paint()
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = t.accent.withValues(alpha: .7));
      return;
    }
    canvas.drawPath(almond, Paint()
      ..color = iris.withValues(alpha: .35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * .15));
    canvas.save();
    canvas.clipPath(almond);
    final box = Rect.fromCenter(center: c, width: w, height: h);
    canvas.drawRect(
      box,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFF3A4A30), Color(0xFF101810)]).createShader(box),
    );
    final vessel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.5, w * .03)
      ..color = t.fail.withValues(alpha: .6);
    for (final s in const [-1.0, 1.0]) {
      final corner = Offset(c.dx + s * w * .46, c.dy);
      canvas
        ..drawLine(corner, corner + Offset(-s * w * .2, -h * .18), vessel)
        ..drawLine(corner, corner + Offset(-s * w * .16, h * .2), vessel);
    }
    final ic = c + Offset(gaze * w * .2, 0);
    final ir = h * .44;
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
    // Smal lodrät pupill — reptil, inte groda.
    canvas.drawOval(Rect.fromCenter(center: ic, width: math.max(1.4, h * .14), height: h * .82), Paint()..color = t.background);
    canvas.drawCircle(ic + Offset(-ir * .4, -ir * .45), math.max(.8, ir * .14), Paint()..color = Colors.white.withValues(alpha: .5));
    canvas.restore();
    canvas.drawPath(almond, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..color = t.accent.withValues(alpha: .8));
  }

  @override
  bool shouldRepaint(_EyeMarkPainter old) => true;
}

class _TracePainter extends CustomPainter {
  _TracePainter({required this.color, required this.inset, required this.head});

  final Color color;
  final double inset;

  /// Spårets huvud som andel av konturen; null = stillastående kant.
  final double? head;

  /// Spårets längd som andel av konturen.
  static const _length = .2;
  static const _slices = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final path = ChevronBorder(inset: inset).getOuterPath(Offset.zero & size);
    final metric = path.computeMetrics().first;
    final total = metric.length;
    final h = head;
    if (h == null) {
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: .7));
      return;
    }
    // Raka skivändar: rundade ändar överlappar och gör svansen prickig.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // Svansen i skivor som tonar ut bakåt; ljusast vid huvudet.
    final seg = total * _length / _slices;
    final end = h * total;
    for (var i = 0; i < _slices; i++) {
      final t = (i + 1) / _slices; // 0 = svansens slut, 1 = huvudet
      final a = end - total * _length + i * seg;
      final piece = _extract(metric, a, a + seg, total);
      final alpha = math.pow(t, 1.6).toDouble();
      canvas.drawPath(piece, glow..color = color.withValues(alpha: .6 * alpha));
      canvas.drawPath(piece, core..color = Color.lerp(color, Colors.white, .35 * alpha)!.withValues(alpha: alpha));
    }
    // Huvudet: en liten ljuspunkt.
    final tip = metric.getTangentForOffset(end % total)?.position;
    if (tip != null) {
      canvas.drawCircle(tip, 3, Paint()
        ..color = color.withValues(alpha: .7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }

  /// Bit av konturen mellan [from] och [to] (får gå runt starten).
  Path _extract(PathMetric m, double from, double to, double total) {
    var a = from % total;
    if (a < 0) a += total;
    final b = a + (to - from);
    if (b <= total) return m.extractPath(a, b);
    return m.extractPath(a, total)..addPath(m.extractPath(0, b - total), Offset.zero);
  }

  @override
  bool shouldRepaint(_TracePainter old) => old.head != head || old.color != color || old.inset != inset;
}
