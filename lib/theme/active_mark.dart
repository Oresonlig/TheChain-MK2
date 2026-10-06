/// Pågående pass i kedjan: temats [ActiveMark] runt fliken (pricken står kvar).
/// Nanosuit (Niklas 2026-10-03): ett kort blått ljusspår som löper runt
/// chevron-konturen — sticker ut men tar inte över. Cosmic Horror: pricken
/// blir ett öga ([ActiveDot]) och fliken får ingen ram. Rörlig bakgrund av
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
    // Ögat bor i pricken ([ActiveDot]) — fliken får ingen ram.
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

/// Pågående-pricken bredvid passnamnet: en grön prick, eller temats öga
/// (Cosmic Horror). [animate] = användarens ambient-inställning.
class ActiveDot extends StatelessWidget {
  const ActiveDot({super.key, this.animate = true});
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    if (c.activeMark == ActiveMark.eye) return Eye(animate: animate);
    return Container(width: 6, height: 6, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle));
  }
}

/// Nästa blinkning: 2,5–9 s bort, aldrig i takt (Niklas 2026-10-06: "inte
/// alltid var 3:e sekund"). Ibland en dubbelblinkning direkt efter.
Duration nextBlink(math.Random r) => Duration(milliseconds: 2500 + r.nextInt(6500));

/// Ett smalt, vaket öga: mandelform, grön iris, lodrät pupill. Blinkar med
/// slumpad takt och flyttar blicken ibland. Stilla = öppet, rakt fram.
class Eye extends StatefulWidget {
  const Eye({super.key, this.animate = true, this.random});
  final bool animate;
  final math.Random? random;

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
    return AnimatedBuilder(
      animation: _blink,
      builder: (context, _) {
        // Stäng snabbt, öppna lite långsammare.
        final t = _blink.value;
        final open = t < .4 ? 1 - t / .4 : (t - .4) / .6;
        return CustomPaint(
          size: const Size(18, 11),
          painter: _EyePainter(
            open: open.clamp(.06, 1.0),
            gaze: _gaze,
            white: c.accentBright,
            iris: c.success,
            pupil: c.background,
          ),
        );
      },
    );
  }
}

class _EyePainter extends CustomPainter {
  const _EyePainter({required this.open, required this.gaze, required this.white, required this.iris, required this.pupil});
  final double open, gaze;
  final Color white, iris, pupil;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, cy = h / 2;
    final lid = h / 2 * open;
    final almond = Path()
      ..moveTo(0, cy)
      ..quadraticBezierTo(w / 2, cy - lid * 2, w, cy)
      ..quadraticBezierTo(w / 2, cy + lid * 2, 0, cy)
      ..close();
    canvas.drawPath(almond, Paint()
      ..color = iris.withValues(alpha: .5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.save();
    canvas.clipPath(almond);
    canvas.drawPath(almond, Paint()..color = white.withValues(alpha: .9));
    final ic = Offset(w / 2 + gaze * w * .18, cy);
    canvas.drawCircle(ic, h * .38, Paint()..color = iris);
    canvas.drawOval(Rect.fromCenter(center: ic, width: h * .16, height: h * .62), Paint()..color = pupil);
    canvas.restore();
    canvas.drawPath(almond, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = white);
  }

  @override
  bool shouldRepaint(_EyePainter old) => old.open != open || old.gaze != gaze || old.iris != iris;
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
