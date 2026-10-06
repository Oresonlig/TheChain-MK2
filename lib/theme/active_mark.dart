/// Pågående pass i kedjan: temats [ActiveMark] runt fliken (pricken står kvar).
/// Nanosuit (Niklas 2026-10-03): ett kort blått ljusspår som löper runt
/// chevron-konturen — sticker ut men tar inte över. Cosmic Horror: ett
/// hjärtslag. Rörlig bakgrund av eller systemets "minska rörelse" →
/// stillastående kant/sken i samma färg.
library;

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
    this.seed,
  });

  /// Passet pågår.
  final bool active;
  final Widget child;

  /// Användarens ambient-inställning.
  final bool animate;

  /// Samma avfasning som [Raised] runt barnet.
  final double inset;

  /// Samma blob-frö som [Raised] runt barnet.
  final int? seed;

  @override
  State<ActiveMarkFrame> createState() => _ActiveMarkFrameState();
}

class _ActiveMarkFrameState extends State<ActiveMarkFrame> with SingleTickerProviderStateMixin {
  /// Ett varv: lugnt nog att märkas i ögonvrån utan att dra blicken.
  static const lap = Duration(milliseconds: 4000);

  /// Ett hjärtslag (lub-dub + vila): vilopuls, inte stress.
  static const beat = Duration(milliseconds: 1700);
  late final AnimationController _ctl = AnimationController(vsync: this, duration: lap);

  bool _moving(ActiveMark mark) =>
      widget.active &&
      mark != ActiveMark.none &&
      widget.animate &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _sync() {
    final mark = context.chain.activeMark;
    final d = mark == ActiveMark.heartbeat ? beat : lap;
    if (_ctl.duration != d) _ctl.duration = d;
    if (_moving(mark)) {
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
    final moving = _moving(c.activeMark);
    if (c.activeMark == ActiveMark.heartbeat) {
      final shape = raisedShape(c, inset: widget.inset, seed: widget.seed);
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctl,
          child: widget.child,
          builder: (context, child) {
            final beat = moving ? heartbeat(_ctl.value) : .5;
            // Membranet andas: knappt synligt, men fliken lever.
            return Transform.scale(
              scale: 1 + .025 * beat,
              child: CustomPaint(
                painter: _HeartbeatPainter(shape: shape, color: c.accentBright, beat: beat),
                child: child,
              ),
            );
          },
        ),
      );
    }
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

/// Hjärtslagets styrka 0–1 över ett slag (t 0–1): lub, dub, vila.
double heartbeat(double t) {
  double pulse(double center, double width) => math.exp(-math.pow((t - center) / width, 2).toDouble());
  return math.min(1.0, pulse(.08, .05) + .7 * pulse(.26, .055));
}

/// Cosmic Horror: ett sken som slår ut från fliken i hjärtats takt.
class _HeartbeatPainter extends CustomPainter {
  _HeartbeatPainter({required this.shape, required this.color, required this.beat});
  final ShapeBorder shape;
  final Color color;
  final double beat;

  @override
  void paint(Canvas canvas, Size size) {
    final path = shape.getOuterPath(Offset.zero & size);
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 + 4 * beat
      ..color = color.withValues(alpha: .15 + .45 * beat)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + 6 * beat));
  }

  @override
  bool shouldRepaint(_HeartbeatPainter old) => old.beat != beat || old.color != color;
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
