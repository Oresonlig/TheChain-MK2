/// Grafernas data — ren Dart, testbar utan UI. Ritningen bor i chain_chart.dart.
/// Värdena är redan i visningsenhet (kg/lbs, min …) så att axelstegen blir jämna.
library;

import 'dart:math' as math;

enum ChartRange {
  m1('1M'),
  m3('3M'),
  ytd('YTD'),
  y1('1Y'),
  all('ALL'),

  /// Egen period (t.ex. en deff i april) — från/till väljs i en datumväljare.
  custom('CUSTOM');

  const ChartRange(this.label);
  final String label;

  /// Första dagen som visas, eller null = allt (och för custom, se [ChartWindow]).
  DateTime? start(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      ChartRange.m1 => DateTime(today.year, today.month - 1, today.day),
      ChartRange.m3 => DateTime(today.year, today.month - 3, today.day),
      ChartRange.ytd => DateTime(today.year),
      ChartRange.y1 => DateTime(today.year - 1, today.month, today.day),
      ChartRange.all || ChartRange.custom => null,
    };
  }
}

/// Det synliga fönstret: från (null = första datapunkten) till och med [to].
class ChartWindow {
  const ChartWindow(this.from, this.to, this.label);

  /// Ett förvalt intervall, fram till idag.
  factory ChartWindow.of(ChartRange r, DateTime now) =>
      ChartWindow(r.start(now), DateTime(now.year, now.month, now.day), r.label);

  final DateTime? from;
  final DateTime to;

  /// "3M" eller "1 Apr–30 Apr".
  final String label;

  bool contains(DateTime d) => (from == null || !d.isBefore(from!)) && d.isBefore(to.add(const Duration(days: 1)));
}

/// En punkt i grafen. [highlight] = PR-markering. [label] visas när tummen
/// drar över punkten ("12 Sep · 130 kg × 1 · PR").
class ChartPoint {
  const ChartPoint(this.x, this.y, {this.highlight = false, this.label = ''});
  final DateTime x;
  final double y;
  final bool highlight;
  final String label;
}

/// Allt en graf ritar.
class ChartSeries {
  const ChartSeries({
    required this.dots,
    required this.line,
    this.steps = const [],
    this.goal,
    this.gapDays,
    required this.from,
    required this.to,
    required this.formatY,
  });

  /// Punkterna (pass eller vägningar).
  final List<ChartPoint> dots;

  /// Den glödande linjen: samma punkter (PR) eller trenden (vikt).
  final List<ChartPoint> line;

  /// "Bästa hittills" som trappsteg: (från, nivå). Ritas till nästa steg / slutet.
  final List<ChartPoint> steps;

  /// Målvikt (streckad), om satt.
  final double? goal;

  /// Längre uppehåll än så ritas streckat i stället för heldraget.
  final int? gapDays;

  /// Synligt tidsfönster.
  final DateTime from;
  final DateTime to;

  /// Axeltext för ett värde ("130", "5:10").
  final String Function(double) formatY;

  bool get isEmpty => dots.isEmpty;

  (double, double) get yRange {
    final ys = [...dots.map((p) => p.y), ...line.map((p) => p.y), ...steps.map((p) => p.y), ?goal];
    final lo = ys.reduce(math.min), hi = ys.reduce(math.max);
    if (hi - lo < 1e-9) {
      final pad = hi.abs() < 1 ? 1.0 : hi.abs() * 0.05;
      return (lo - pad, hi + pad);
    }
    final pad = (hi - lo) * 0.12;
    return (lo - pad, hi + pad);
  }
}

/// Bara det som ligger i fönstret.
List<T> inWindow<T>(List<T> items, DateTime Function(T) dateOf, ChartWindow w) =>
    items.where((e) => w.contains(dateOf(e))).toList();

/// "Bästa hittills": ett steg per PR i fönstret. Ett PR satt före fönstret syns
/// ändå — det blir första steget, vid fönstrets början (Niklas: se hur långt
/// ifrån det bästa man ligger, även i månadsvyn).
List<ChartPoint> bestSoFarSteps(List<ChartPoint> all, ChartWindow w) {
  final prs = all.where((p) => p.highlight).toList();
  final from = w.from;
  final before = from == null ? null : prs.where((p) => p.x.isBefore(from)).lastOrNull;
  return [
    if (before != null) ChartPoint(from!, before.y),
    ...prs.where((p) => w.contains(p.x)),
  ];
}

/// Tidsviktad exponentiell trend: varje vägning drar trenden mot sig med en
/// andel som växer med dagarna sedan förra (tidskonstant [tauDays]). Mjuk även
/// när man väger sig glest — ett glidande medel hoppar varje gång en vägning
/// faller ur fönstret.
List<ChartPoint> trendLine(List<ChartPoint> pts, {double tauDays = 20}) {
  final out = <ChartPoint>[];
  for (final p in pts) {
    if (out.isEmpty) {
      out.add(ChartPoint(p.x, p.y));
      continue;
    }
    final prev = out.last;
    final dt = p.x.difference(prev.x).inHours / 24;
    final a = 1 - math.exp(-dt / tauDays);
    out.add(ChartPoint(p.x, prev.y + a * (p.y - prev.y)));
  }
  return out;
}

/// 2–4 jämna axelsteg inom [lo, hi] (1, 2, 2.5 eller 5 × 10^n).
List<double> niceTicks(double lo, double hi, {int target = 3}) {
  final span = hi - lo;
  if (span <= 0 || !span.isFinite) return [lo];
  final mag = math.pow(10, (math.log(span / target) / math.ln10).floor()).toDouble();
  List<double> ticks(double step) {
    final first = (lo / step).ceil() * step;
    return [for (var v = first; v <= hi + 1e-9; v += step) double.parse(v.toStringAsFixed(6))];
  }

  // Minsta jämna steg som ger högst target+1 linjer.
  for (final m in [mag / 10, mag, mag * 10]) {
    for (final f in [1.0, 2.0, 2.5, 5.0]) {
      final t = ticks(m * f);
      if (t.length <= target + 1) return t;
    }
  }
  return ticks(mag * 100);
}
