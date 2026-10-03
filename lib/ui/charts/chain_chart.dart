/// Egen ritkod för graferna (Niklas 2026-10-03: inte "Excel-vibbar").
/// Ingen ram, inget rutnät — bara svaga riktlinjer; mjuk glödande linje med
/// toning under; PR som glödande ringar; "bästa hittills" som streckade
/// trappsteg; långa uppehåll streckade; linjen ritas fram när vyn öppnas.
/// Tummen över grafen visar en etikett för närmaste punkt. Allt i temats färger.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import 'chart_data.dart';
import 'series.dart';

class ChainChart extends StatefulWidget {
  const ChainChart({super.key, required this.series, this.height = 220, this.animate = true});

  final ChartSeries series;
  final double height;

  /// Framritningen (av när rörlig bakgrund eller "minska rörelse" är av).
  final bool animate;

  @override
  State<ChainChart> createState() => _ChainChartState();
}

class _ChainChartState extends State<ChainChart> with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  int? _scrub;

  bool get _animate => widget.animate && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draw.status == AnimationStatus.dismissed) _start();
  }

  @override
  void didUpdateWidget(ChainChart old) {
    super.didUpdateWidget(old);
    // Nytt intervall → rita fram igen.
    if (old.series.from != widget.series.from || old.series.dots.length != widget.series.dots.length) {
      _scrub = null;
      _start();
    }
  }

  void _start() {
    if (_animate) {
      _draw.forward(from: 0);
    } else {
      _draw.value = 1;
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  void _scrubAt(double dx, _Geometry g) {
    final dots = widget.series.dots;
    if (dots.isEmpty) return;
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < dots.length; i++) {
      final d = (g.x(dots[i].x) - dx).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (best != _scrub) setState(() => _scrub = best);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final s = widget.series;
    if (s.isEmpty) {
      return SizedBox(height: widget.height, child: Center(child: Text('No data in this period', style: text.bodySmall)));
    }
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(builder: (context, box) {
        final g = _Geometry(s, Size(box.maxWidth, widget.height));
        final sel = _scrub == null ? null : s.dots[_scrub!];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _scrubAt(d.localPosition.dx, g),
          onHorizontalDragStart: (d) => _scrubAt(d.localPosition.dx, g),
          onHorizontalDragUpdate: (d) => _scrubAt(d.localPosition.dx, g),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _draw,
                builder: (context, _) => CustomPaint(
                  painter: _ChartPainter(
                    s,
                    g,
                    c,
                    TextStyle(fontFamily: text.labelSmall?.fontFamily, fontSize: 10, color: c.textFaint, letterSpacing: .5),
                    Curves.easeOutCubic.transform(_draw.value),
                    sel,
                  ),
                ),
              ),
            ),
            if (sel != null)
              Positioned(
                top: 0,
                left: (g.x(sel.x) - 90).clamp(0, math.max(0, box.maxWidth - 180)).toDouble(),
                width: 180,
                child: IgnorePointer(
                  child: Center(
                    child: Glass(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(sel.label,
                          textAlign: TextAlign.center,
                          style: text.labelSmall!.copyWith(color: sel.highlight ? c.accentBright : c.textStrong)),
                    ),
                  ),
                ),
              ),
          ]),
        );
      }),
    );
  }
}

/// Värde/tid → pixlar.
class _Geometry {
  _Geometry(this.s, this.size) {
    final (lo, hi) = s.yRange;
    yLo = lo;
    yHi = hi;
    var a = s.from.millisecondsSinceEpoch.toDouble(), b = s.to.millisecondsSinceEpoch.toDouble();
    if (b - a < 1) {
      a -= 86400000;
      b += 86400000;
    }
    t0 = a;
    t1 = b;
    plot = Rect.fromLTRB(6, 34, size.width - 44, size.height - 22);
  }

  final ChartSeries s;
  final Size size;
  late final double yLo, yHi, t0, t1;
  late final Rect plot;

  double x(DateTime d) => plot.left + (d.millisecondsSinceEpoch - t0) / (t1 - t0) * plot.width;
  double y(double v) => plot.bottom - (v - yLo) / (yHi - yLo) * plot.height;
  Offset at(ChartPoint p) => Offset(x(p.x), y(p.y));
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.s, this.g, this.c, this.label, this.progress, this.sel);

  final ChartSeries s;
  final _Geometry g;
  final ChainTheme c;
  final TextStyle label;
  final double progress;
  final ChartPoint? sel;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = g.plot;

    // Riktlinjer + värden i högerkanten (ingen ram, inget lodrätt rutnät).
    final guide = Paint()
      ..color = c.border.withValues(alpha: .55)
      ..strokeWidth = 1;
    for (final t in niceTicks(g.yLo, g.yHi)) {
      final y = g.y(t);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), guide);
      _text(canvas, s.formatY(t), Offset(plot.right + 8, y), alignY: .5);
    }
    // Datum bara i ändarna.
    _text(canvas, _date(s.from), Offset(plot.left, plot.bottom + 6));
    _text(canvas, _date(s.to), Offset(plot.right, plot.bottom + 6), alignX: 1);

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, plot.left + plot.width * progress + 12, size.height));

    // Målvikt.
    if (s.goal case final goal?) {
      final y = g.y(goal);
      _dashed(canvas, Offset(plot.left, y), Offset(plot.right, y), Paint()
        ..color = c.success.withValues(alpha: .6)
        ..strokeWidth = 1.2);
      _text(canvas, 'GOAL', Offset(plot.left + 2, y - 3), alignY: 1, color: c.success.withValues(alpha: .8));
    }

    // Bästa hittills: streckade trappsteg.
    if (s.steps.isNotEmpty) {
      final p = Paint()
        ..color = c.accentBright.withValues(alpha: .45)
        ..strokeWidth = 1.2;
      for (var i = 0; i < s.steps.length; i++) {
        final a = g.at(s.steps[i]);
        final endX = i + 1 < s.steps.length ? g.x(s.steps[i + 1].x) : plot.right;
        _dashed(canvas, a, Offset(endX, a.dy), p);
        if (i + 1 < s.steps.length) _dashed(canvas, Offset(endX, a.dy), Offset(endX, g.y(s.steps[i + 1].y)), p);
      }
      // Etikett vid det gällande (sista) steget, i högerkanten av linjen.
      _text(canvas, 'BEST', Offset(plot.right - 2, g.y(s.steps.last.y) - 3),
          alignX: 1, alignY: 1, color: c.accentBright.withValues(alpha: .7));
    }

    // Linjen: sammanhängande bitar mjukt böjda, uppehåll streckade.
    final runs = _runs(s.line);
    final area = Paint()
      ..shader = ui.Gradient.linear(Offset(0, plot.top), Offset(0, plot.bottom),
          [c.accent.withValues(alpha: .26), c.accent.withValues(alpha: 0)]);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = c.accent.withValues(alpha: .35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c.accent;
    for (var r = 0; r < runs.length; r++) {
      final pts = runs[r].map(g.at).toList();
      if (pts.length > 1) {
        final path = _smooth(pts);
        canvas.drawPath(
            Path.from(path)
              ..lineTo(pts.last.dx, plot.bottom)
              ..lineTo(pts.first.dx, plot.bottom)
              ..close(),
            area);
        canvas.drawPath(path, glow);
        canvas.drawPath(path, stroke);
      }
      if (r + 1 < runs.length) {
        _dashed(canvas, pts.last, g.at(runs[r + 1].first), Paint()
          ..color = c.accent.withValues(alpha: .5)
          ..strokeWidth = 1.5);
      }
    }

    // Punkter: vanliga små och dämpade, PR stora med ring och glöd.
    final dot = Paint()..color = c.accent.withValues(alpha: .75);
    for (final p in s.dots.where((p) => !p.highlight)) {
      canvas.drawCircle(g.at(p), 2.6, dot);
    }
    // PR: fylld kärna + tunn ring + lätt glöd. Dämpad nog att en lång stigande
    // serie av PR inte blir en enda glödande korv.
    for (final p in s.dots.where((p) => p.highlight)) {
      final o = g.at(p);
      canvas.drawCircle(o, 6, Paint()
        ..color = c.accentBright.withValues(alpha: .3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(o, 5.5, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = c.accentBright.withValues(alpha: .6));
      canvas.drawCircle(o, 3.4, Paint()..color = c.accentBright);
    }
    canvas.restore();

    // Tummens markör.
    if (sel case final p?) {
      final o = g.at(p);
      canvas.drawLine(Offset(o.dx, plot.top), Offset(o.dx, plot.bottom), Paint()
        ..color = c.textMuted.withValues(alpha: .5)
        ..strokeWidth = 1);
      canvas.drawCircle(o, 6, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = c.textStrong);
    }
  }

  /// Delar linjen där uppehållet är längre än gapDays.
  List<List<ChartPoint>> _runs(List<ChartPoint> pts) {
    if (pts.isEmpty) return const [];
    final out = <List<ChartPoint>>[
      [pts.first],
    ];
    for (var i = 1; i < pts.length; i++) {
      final gap = s.gapDays != null && pts[i].x.difference(pts[i - 1].x).inDays > s.gapDays!;
      if (gap) {
        out.add([pts[i]]);
      } else {
        out.last.add(pts[i]);
      }
    }
    return out;
  }

  /// Monoton kubisk kurva (Fritsch–Carlson): mjuk, men hittar aldrig på toppar
  /// eller dalar som inte finns mellan två punkter.
  Path _smooth(List<Offset> p) {
    final n = p.length;
    final d = List<double>.generate(n - 1, (i) {
      final dx = p[i + 1].dx - p[i].dx;
      return dx.abs() < 1e-6 ? 0 : (p[i + 1].dy - p[i].dy) / dx;
    });
    final m = List<double>.filled(n, 0);
    m[0] = d[0];
    m[n - 1] = d[n - 2];
    for (var i = 1; i < n - 1; i++) {
      m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2;
    }
    for (var i = 0; i < n - 1; i++) {
      if (d[i] == 0) {
        m[i] = 0;
        m[i + 1] = 0;
        continue;
      }
      final a = m[i] / d[i], b = m[i + 1] / d[i];
      final h = a * a + b * b;
      if (h > 9) {
        final t = 3 / math.sqrt(h);
        m[i] = t * a * d[i];
        m[i + 1] = t * b * d[i];
      }
    }
    final path = Path()..moveTo(p[0].dx, p[0].dy);
    for (var i = 0; i < n - 1; i++) {
      final dx = (p[i + 1].dx - p[i].dx) / 3;
      path.cubicTo(p[i].dx + dx, p[i].dy + m[i] * dx, p[i + 1].dx - dx, p[i + 1].dy - m[i + 1] * dx, p[i + 1].dx, p[i + 1].dy);
    }
    return path;
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint, {double dash = 4, double gap = 4}) {
    final len = (b - a).distance;
    if (len < 0.5) return;
    final dir = (b - a) / len;
    for (var t = 0.0; t < len; t += dash + gap) {
      canvas.drawLine(a + dir * t, a + dir * math.min(t + dash, len), paint);
    }
  }

  void _text(Canvas canvas, String t, Offset at, {double alignX = 0, double alignY = 0, Color? color}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: color == null ? label : label.copyWith(color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width * alignX, tp.height * alignY));
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} \'${(d.year % 100).toString().padLeft(2, '0')}';

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}

/// Intervallet för en graf: förval (sparas per graf) eller CUSTOM via datumväljare.
/// Delas av viktgrafen och PR-graferna.
mixin ChartRangeState<T extends StatefulWidget> on State<T> {
  /// Nyckel för det sparade valet ("weight", "pr").
  String get rangeKey;

  ChartRange range = ChartRange.all;
  DateTimeRange? custom;

  void loadSavedRange() => loadRange(rangeKey, ChartRange.all).then((r) {
        if (mounted) setState(() => range = r);
      });

  ChartWindow window(DateTime now) {
    final c = custom;
    if (range == ChartRange.custom && c != null) {
      return ChartWindow(c.start, c.end, windowLabel(c.start, c.end, now));
    }
    return ChartWindow.of(range == ChartRange.custom ? ChartRange.all : range, now);
  }

  Future<void> selectRange(ChartRange r) async {
    if (r != ChartRange.custom) {
      setState(() => range = r);
      saveRange(rangeKey, r);
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: custom ?? DateTimeRange(start: DateTime(today.year, today.month - 1, today.day), end: today),
      helpText: 'Choose a period',
    );
    if (picked != null && mounted) {
      setState(() {
        custom = picked;
        range = ChartRange.custom;
      });
    }
  }
}

/// Intervallchips ovanför en graf: 1M · 3M · YTD · 1Y · ALL · (egen period).
class RangeChips extends StatelessWidget {
  const RangeChips({super.key, required this.value, required this.onChanged});
  final ChartRange value;
  final ValueChanged<ChartRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return Row(children: [
      for (final r in ChartRange.values)
        Expanded(
          child: Semantics(
            button: true,
            selected: r == value,
            label: r.label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(r),
              child: SizedBox(
                height: 44,
                child: r == value
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                        child: Raised(
                          material: c.raisedActive,
                          inset: 6,
                          padding: EdgeInsets.zero,
                          child: Center(child: _label(r, c.textStrong, text)),
                        ),
                      )
                    : Center(child: _label(r, c.textMuted, text)),
              ),
            ),
          ),
        ),
    ]);
  }

  // CUSTOM är för brett för en sjättedel av raden — en kalenderikon.
  Widget _label(ChartRange r, Color color, TextTheme text) => r == ChartRange.custom
      ? Icon(Icons.date_range, size: 18, color: color)
      : Text(r.label, style: text.labelSmall!.copyWith(color: color));
}
