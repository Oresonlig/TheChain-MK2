/// Pågående pass i kedjan: temats [ActiveMark] runt fliken (pricken står kvar).
/// Nanosuit (Niklas 2026-10-03): ett kort blått ljusspår som löper runt
/// chevron-konturen — sticker ut men tar inte över. Rörlig bakgrund av eller
/// systemets "minska rörelse" → stillastående kant i samma färg.
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

  /// Dimman sjunker långsammare än spåret löper.
  static const mistCycle = Duration(milliseconds: 6000);

  bool _moving(ActiveMark mark) =>
      widget.active &&
      mark != ActiveMark.none &&
      widget.animate &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _sync() {
    final mark = context.chain.activeMark;
    final d = mark == ActiveMark.nitrogen ? mistCycle : lap;
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
    if (c.activeMark == ActiveMark.nitrogen) {
      return AnimatedBuilder(
        animation: _ctl,
        child: widget.child,
        builder: (context, child) => CustomPaint(
          painter: _ColdHaloPainter(color: c.accentBright, t: moving ? _ctl.value : null),
          foregroundPainter: _MistPainter(color: c.accentBright, t: moving ? _ctl.value : null),
          child: child,
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

/// Arctic: ett kallt sken bakom fliken som andas (stilla = jämnt sken).
class _ColdHaloPainter extends CustomPainter {
  _ColdHaloPainter({required this.color, required this.t});
  final Color color;
  final double? t;

  @override
  void paint(Canvas canvas, Size size) {
    final breathe = t == null ? .8 : .55 + .45 * (.5 + .5 * math.sin(t! * 2 * math.pi));
    final r = (Offset.zero & size).inflate(8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(14)),
      Paint()
        ..color = color.withValues(alpha: .16 * breathe)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
  }

  @override
  bool shouldRepaint(_ColdHaloPainter old) => old.t != t || old.color != color;
}

/// Arctic: kvävedimma rinner ner från flikens underkant, glider isär och tonar
/// bort. Fyra tussar i otakt. Stilla → ingen dimma (bara skenet).
class _MistPainter extends CustomPainter {
  _MistPainter({required this.color, required this.t});
  final Color color;
  final double? t;

  static const _puffs = [(.08, -14.0), (.36, -4.0), (.62, 6.0), (.88, 16.0)];

  @override
  void paint(Canvas canvas, Size size) {
    final v = t;
    if (v == null) return;
    for (final (i, (x, dx)) in _puffs.indexed) {
      final p = (v + i / _puffs.length) % 1.0;
      // In snabbt, ut långsamt.
      final alpha = p < .18 ? p / .18 : 1 - (p - .18) / .82;
      final c = Offset(size.width * x + dx * p, size.height - 3 + 22 * p);
      final r = 10 + 16 * p;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 3, height: r),
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: .75 * alpha),
            color.withValues(alpha: .35 * alpha),
            color.withValues(alpha: 0),
          ], stops: const [0, .5, 1])
              .createShader(Rect.fromCenter(center: c, width: r * 3, height: r))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(_MistPainter old) => old.t != t || old.color != color;
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
