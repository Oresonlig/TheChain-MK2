/// Pågående pass i kedjan: temats [ActiveMark] runt fliken (pricken står kvar).
/// Nanosuit (Niklas 2026-10-03): ett kort blått ljusspår som löper runt
/// chevron-konturen — sticker ut men tar inte över. Rörlig bakgrund av eller
/// systemets "minska rörelse" → stillastående kant i samma färg.
/// Cosmic Horrors ögon: [EyeTab] (eye_tab.dart).
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

  /// Sakuras ljusband (Claude Design: 3,2 s).
  static const rimLap = Duration(milliseconds: 3200);
  late final AnimationController _ctl = AnimationController(vsync: this, duration: lap);

  static bool _drawn(ActiveMark mark) => mark == ActiveMark.tracePulse || mark == ActiveMark.rimSweep;

  bool _moving(ActiveMark mark) =>
      widget.active &&
      _drawn(mark) &&
      widget.animate &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _sync() {
    final mark = context.chain.activeMark;
    final lapFor = mark == ActiveMark.rimSweep ? rimLap : lap;
    if (_ctl.duration != lapFor) _ctl.duration = lapFor;
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
    if (!widget.active || !_drawn(c.activeMark)) return widget.child;
    final moving = _moving(c.activeMark);
    final shape = raisedShape(c, inset: widget.inset);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctl,
        child: widget.child,
        builder: (context, child) => CustomPaint(
          foregroundPainter: c.activeMark == ActiveMark.rimSweep
              ? RimPainter(shape: shape, edge: c.raisedActive.edge, soft: rimSoft(c), turn: moving ? _ctl.value : null)
              : _TracePainter(color: c.accentBright, shape: shape, head: moving ? _ctl.value : null),
          child: child,
        ),
      ),
    );
  }
}

/// Ljusbandets mjuka färg (Claude Design #EFA3D8 för Orchid) — härledd ur
/// temats accentBright, så den följer en ändrad accent.
Color rimSoft(ChainTheme c) => Color.lerp(c.accentBright, const Color(0xFFFFFFFF), .4)!;

/// Primärknappens kant (START SESSION, aktiv FINISH SESSION): Sakuras kant
/// stillastående — "det lilla extra" utan rörelse (rörelse = pågående pass).
/// Andra teman: bara barnet.
class PrimaryRim extends StatelessWidget {
  const PrimaryRim({super.key, required this.enabled, required this.child, this.inset = 8});

  final bool enabled;
  final Widget child;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    if (!enabled || c.activeMark != ActiveMark.rimSweep) return child;
    return CustomPaint(
      foregroundPainter: RimPainter(shape: raisedShape(c, inset: inset), edge: c.raisedActive.edge, soft: rimSoft(c), turn: null),
      child: child,
    );
  }
}

/// Kanten mellan formen och samma form [width] dp indragen (Claude Design:
/// två fyllda paths, aldrig en stroke — stroke ger spikar i V:et; aldrig
/// skugga — den blir rektangulär). Ritas som ringen yttre − inre, så knappens
/// eget material under står orört.
class RimPainter extends CustomPainter {
  RimPainter({required this.shape, required this.edge, required this.soft, required this.turn});

  final OutlinedBorder shape;
  final Color edge, soft;

  /// Ljusbandets vridning (0–1); null = stillastående kant, ljus överst.
  final double? turn;

  static const width = 1.5;

  /// Ringen mellan ytter- och innerform.
  static Path ring(OutlinedBorder shape, Size size) => Path.combine(
        PathOperation.difference,
        shape.getOuterPath(Offset.zero & size),
        shape.getOuterPath((Offset.zero & size).deflate(width)),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final t = turn;
    final paint = Paint()..isAntiAlias = true;
    paint.shader = t == null
        ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [soft, edge]).createShader(rect)
        : SweepGradient(
            colors: [edge, edge, soft, const Color(0xFFFFFFFF), soft, edge, edge],
            stops: const [0, .62, .74, .79, .84, .96, 1],
            // CSS conic börjar klockan 12, Flutters sweep klockan 3.
            transform: GradientRotation(t * 2 * math.pi - math.pi / 2),
          ).createShader(rect);
    canvas.drawPath(ring(shape, size), paint);
  }

  @override
  bool shouldRepaint(RimPainter old) =>
      old.turn != turn || old.shape != shape || old.edge != edge || old.soft != soft;
}

class _TracePainter extends CustomPainter {
  _TracePainter({required this.color, required this.shape, required this.head});

  final Color color;

  /// Flikens kontur (temats [TabShape]) — spåret följer den.
  final OutlinedBorder shape;

  /// Spårets huvud som andel av konturen; null = stillastående kant.
  final double? head;

  /// Spårets längd som andel av konturen.
  static const _length = .2;
  static const _slices = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final path = shape.getOuterPath(Offset.zero & size);
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
  bool shouldRepaint(_TracePainter old) => old.head != head || old.color != color || old.shape != shape;
}
