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

/// Cosmic Horror: det pågående passets HELA flik är ett öga (Niklas
/// 2026-10-06: den lilla pricken-ögat var för litet). Mandelform, blodsprängt
/// vitöga, grön iris — och passets bokstav är pupillen. Passnamnet står i
/// kortet under kedjan. Blinkar med slumpad takt och flyttar blicken.
/// NÄRHET bor fortfarande på behållaren: vald = större öga, ljusare kant.
/// Stilla (minska rörelse / ambient av) = öppet, rakt fram.
class Eye extends StatefulWidget {
  const Eye({super.key, required this.letter, required this.selected, this.animate = true, this.random});
  final String letter;
  final bool selected;
  final bool animate;
  final math.Random? random;

  static const height = 52.0;
  static double widthFor({required bool selected}) => selected ? 132 : 96;

  @override
  State<Eye> createState() => _EyeState();
}

class _EyeState extends State<Eye> with SingleTickerProviderStateMixin {
  late final math.Random _r = widget.random ?? math.Random();
  late final AnimationController _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  Timer? _timer;
  double _gaze = 0; // -1 vänster … 1 höger

  bool get _moving => widget.animate && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Eye old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_moving && _timer == null) {
      _schedule();
    } else if (!_moving) {
      _timer?.cancel();
      _timer = null;
      _blink.value = 0;
      _gaze = 0;
    }
  }

  void _schedule() {
    _timer = Timer(nextBlink(_r), () async {
      if (!mounted) return;
      await _blink.forward(from: 0);
      if (!mounted) return;
      // Ögat tittar någon annanstans när det öppnas igen.
      setState(() => _gaze = _r.nextDouble() < .5 ? 0 : (_r.nextDouble() * 2 - 1));
      if (_r.nextDouble() < .2) await _blink.forward(from: 0); // dubbelblink
      if (mounted && _moving) _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final letter = Theme.of(context).textTheme.labelLarge!.copyWith(
          fontSize: 24,
          color: c.background,
          fontVariations: const [FontVariation.weight(900)],
        );
    final size = Size(Eye.widthFor(selected: widget.selected), Eye.height);
    return AnimatedBuilder(
      animation: _blink,
      builder: (context, _) {
        // Stäng snabbt, öppna lite långsammare.
        final t = _blink.value;
        final open = t < .4 ? 1 - t / .4 : (t - .4) / .6;
        return CustomPaint(
          size: size,
          painter: _EyePainter(
            open: open.clamp(.04, 1.0),
            gaze: _gaze,
            letter: widget.letter,
            letterStyle: letter,
            selected: widget.selected,
            theme: c,
          ),
        );
      },
    );
  }
}

class _EyePainter extends CustomPainter {
  _EyePainter({
    required this.open,
    required this.gaze,
    required this.letter,
    required this.letterStyle,
    required this.selected,
    required this.theme,
  });
  final double open, gaze;
  final String letter;
  final TextStyle letterStyle;
  final bool selected;
  final ChainTheme theme;

  /// Blodkärl i vitögat: från ögonvrårna inåt (x, y, vinkel, längd).
  static const _vessels = [
    (.06, .5, -.35, .2), (.07, .52, .3, .17), (.1, .48, -.05, .14),
    (.94, .5, math.pi + .35, .2), (.93, .5, math.pi - .3, .16), (.9, .52, math.pi + .05, .13),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = theme;
    final w = size.width, h = size.height, cy = h / 2;
    final lid = h / 2 * open;
    final almond = Path()
      ..moveTo(0, cy)
      ..quadraticBezierTo(w / 2, cy - lid * 2, w, cy)
      ..quadraticBezierTo(w / 2, cy + lid * 2, 0, cy)
      ..close();

    // Ögat lyser svagt ut i mörkret.
    canvas.drawPath(almond, Paint()
      ..color = c.success.withValues(alpha: selected ? .4 : .25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    canvas.save();
    canvas.clipPath(almond);
    // Vitögat: ett blekt, sjukt grönt membran, mörkare mot vrårna.
    final area = Offset.zero & size;
    canvas.drawRect(
      area,
      Paint()
        ..shader = RadialGradient(colors: [
          Color.lerp(c.accentBright, c.surface, .25)!,
          Color.lerp(c.accent, c.surface, .55)!,
        ]).createShader(area),
    );
    final vessel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..strokeCap = StrokeCap.round
      ..color = c.fail.withValues(alpha: .55);
    for (final (x, y, a, l) in _vessels) {
      final p0 = Offset(w * x, h * y);
      final p1 = p0 + Offset.fromDirection(a, w * l);
      final mid = Offset.lerp(p0, p1, .5)! + Offset(0, (a.isNegative ? -1 : 1) * 2.5);
      canvas.drawPath(Path()..moveTo(p0.dx, p0.dy)..quadraticBezierTo(mid.dx, mid.dy, p1.dx, p1.dy), vessel);
    }

    // Irisen följer blicken; bokstaven är pupillen.
    final ic = Offset(w / 2 + gaze * w * .14, cy);
    final ir = h * .4;
    final irisRect = Rect.fromCircle(center: ic, radius: ir);
    canvas.drawCircle(
      ic,
      ir,
      Paint()
        ..shader = RadialGradient(colors: [
          c.accentBright,
          c.success,
          Color.lerp(c.success, c.background, .55)!,
        ], stops: const [0, .55, 1]).createShader(irisRect),
    );
    canvas.drawCircle(ic, ir, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Color.lerp(c.success, c.background, .7)!);
    final tp = TextPainter(text: TextSpan(text: letter, style: letterStyle), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, ic - Offset(tp.width / 2, tp.height / 2));
    // Ögats glans.
    canvas.drawCircle(ic + Offset(-ir * .45, -ir * .45), ir * .16, Paint()..color = Colors.white.withValues(alpha: .55));
    canvas.restore();

    // Ögonlockens kant: ljusare på det valda ögat (närhet).
    canvas.drawPath(almond, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 1.6 : 1
      ..color = selected ? c.accentBright : c.accent.withValues(alpha: .7));
  }

  @override
  bool shouldRepaint(_EyePainter old) =>
      old.open != open || old.gaze != gaze || old.letter != letter || old.selected != selected || old.theme != theme;
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
