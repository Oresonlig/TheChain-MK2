/// Domän → grafserie: kroppsvikt och PR per övning, i visningsenhet.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/domain.dart';
import '../format.dart';
import 'chart_data.dart';

const _lbsPerKg = 2.20462;
const _minus = '−';

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
String _short(DateTime d) => fmtDate(d);

// ── kroppsvikt ──

double _w(double kg, UserSettings s) => s.weightUnit == WeightUnit.lbs ? kg * _lbsPerKg : kg;
String _unit(UserSettings s) => s.weightUnit == WeightUnit.lbs ? 'lbs' : 'kg';

/// Vägningar som punkter, tidsviktad trend som linje (räknad över ALL historik,
/// så trenden i fönstrets början väger in dagarna före), målvikt streckad.
ChartSeries weightSeries(List<BodyweightEntry> entries, ChartRange range, DateTime now, UserSettings s) {
  final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
  final raw = [for (final e in sorted) ChartPoint(DateTime.parse(e.date), _w(e.kg, s))];
  final trend = trendLine(raw);
  final from = range.start(now);
  final dots = <ChartPoint>[];
  final line = <ChartPoint>[];
  for (var i = 0; i < raw.length; i++) {
    if (from != null && raw[i].x.isBefore(from)) continue;
    final p = raw[i], t = trend[i];
    dots.add(ChartPoint(p.x, p.y, label: '${_short(p.x)} · ${_num(p.y)} ${_unit(s)} · trend ${_num(t.y)}'));
    line.add(t);
  }
  return ChartSeries(
    dots: dots,
    line: line,
    goal: s.weightGoalKg == null ? null : _w(s.weightGoalKg!, s),
    gapDays: 30,
    from: from ?? (dots.isEmpty ? _day(now) : dots.first.x),
    to: _day(now),
    formatY: _num,
  );
}

/// "−1.8 kg · 3M": trendens förändring i fönstret, eller null.
String? weightChange(ChartSeries s, ChartRange range, UserSettings settings) {
  if (s.line.length < 2) return null;
  final d = s.line.last.y - s.line.first.y;
  final sign = d > 0.05 ? '+' : (d < -0.05 ? _minus : '±');
  return '$sign${_num(d.abs())} ${_unit(settings)} · ${range.label}';
}

// ── PR per övning ──

/// Lagrat PR-värde → visningsenhet. EN switch över mätsättets PR-regel.
double plotValue(Measure m, double v, UserSettings s) => switch (m.pr) {
      PrMetric.weight || PrMetric.extra => _w(v, s),
      PrMetric.secs => m.minutesInput ? v / 60 : v,
      PrMetric.reps || PrMetric.dist || PrMetric.sprints || PrMetric.pace => v,
    };

String Function(double) axisFormat(Measure m) => switch (m.pr) {
      PrMetric.pace => (v) => fmtPace(v).replaceAll(' /km', ''),
      PrMetric.reps || PrMetric.sprints => (v) => v.round().toString(),
      _ => _num,
    };

/// Ett set per pass (det bästa), alla pass. PR markerade + "bästa hittills".
ChartSeries prSeries(
  List<ProgressionPoint> progression,
  Measure current,
  ChartRange range,
  DateTime now,
  UserSettings s,
  String Function(ProgressionPoint) setText,
) {
  final all = [
    for (final p in progression)
      ChartPoint(
        p.date,
        plotValue(p.measure, p.value, s),
        highlight: p.isPr,
        label: '${_short(p.date)} · ${setText(p)}${p.isPr ? ' · PR' : ''}',
      ),
  ];
  final from = range.start(now);
  final dots = inWindow(all, (p) => p.x, from);
  return ChartSeries(
    dots: dots,
    line: dots,
    steps: bestSoFarSteps(all, from),
    gapDays: 42,
    from: from ?? (dots.isEmpty ? _day(now) : _day(dots.first.x)),
    to: _day(now),
    formatY: axisFormat(current),
  );
}

// ── valt intervall, per graf och enhet (bekvämlighet — får saknas) ──

Future<ChartRange> loadRange(String key, ChartRange fallback) async {
  try {
    final v = (await SharedPreferences.getInstance()).getString('chartRange.$key');
    return ChartRange.values.firstWhere((r) => r.name == v, orElse: () => fallback);
  } catch (_) {
    return fallback;
  }
}

Future<void> saveRange(String key, ChartRange r) async {
  try {
    await (await SharedPreferences.getInstance()).setString('chartRange.$key', r.name);
  } catch (_) {}
}
