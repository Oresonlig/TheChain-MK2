/// Domän → grafserie: kroppsvikt och PR per övning, i visningsenhet.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/domain.dart';
import '../format.dart';
import 'chart_data.dart';

const _lbsPerKg = 2.20462;
const _minus = '−';

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
String _short(DateTime d) => fmtDate(d);

// ── kroppsvikt ──

double _w(double kg, UserSettings s) => s.weightUnit == WeightUnit.lbs ? kg * _lbsPerKg : kg;
String _unit(UserSettings s) => s.weightUnit == WeightUnit.lbs ? 'lbs' : 'kg';

/// Vägningar som punkter, tidsviktad trend som linje (räknad över ALL historik,
/// så trenden i fönstrets början väger in dagarna före), målvikt streckad.
ChartSeries weightSeries(List<BodyweightEntry> entries, ChartWindow w, UserSettings s) {
  final raw = _raw(entries, s);
  final trend = trendLine(raw);
  final dots = <ChartPoint>[];
  final line = <ChartPoint>[];
  for (var i = 0; i < raw.length; i++) {
    if (!w.contains(raw[i].x)) continue;
    final p = raw[i], t = trend[i];
    dots.add(ChartPoint(p.x, p.y, label: '${_short(p.x)} · ${_num(p.y)} ${_unit(s)} · trend ${_num(t.y)}'));
    line.add(t);
  }
  final (from, to) = dataSpan(dots, w);
  return ChartSeries(
    dots: dots,
    line: line,
    goal: s.weightGoalKg == null ? null : _w(s.weightGoalKg!, s),
    gapDays: 30,
    from: from,
    to: to,
    formatY: _num,
  );
}

List<ChartPoint> _raw(List<BodyweightEntry> entries, UserSettings s) {
  final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
  return [for (final e in sorted) ChartPoint(DateTime.parse(e.date), _w(e.kg, s))];
}

String _signed(double d, UserSettings s) {
  final sign = d > 0.05 ? '+' : (d < -0.05 ? _minus : '±');
  return '$sign${_num(d.abs())} ${_unit(s)}';
}

/// "−1.8 kg · 3M": trendens förändring i fönstret, eller null.
String? weightChange(ChartSeries s, ChartWindow w, UserSettings settings) {
  if (s.line.length < 2) return null;
  return '${_signed(s.line.last.y - s.line.first.y, settings)} · ${w.label}';
}

/// Siffrorna under TREND (Niklas 2026-10-03): NOW och TO GOAL på senaste
/// vägningen — efter en 72-timmarsfasta inför tävling är det vågen som gäller,
/// inte trenden. 7 DAYS på trenden, där brus från dag till dag gör mest skada.
class WeightStats {
  const WeightStats({required this.now, this.week, this.toGoal});
  final String now;
  final String? week;
  final String? toGoal;
}

WeightStats? weightStats(List<BodyweightEntry> entries, UserSettings s) {
  final raw = _raw(entries, s);
  if (raw.isEmpty) return null;
  final trend = trendLine(raw);
  final latest = raw.last;
  final weekAgo = latest.x.subtract(const Duration(days: 7));
  final i = trend.lastIndexWhere((p) => !p.x.isAfter(weekAgo));
  final goal = s.weightGoalKg == null ? null : _w(s.weightGoalKg!, s);
  return WeightStats(
    now: '${_num(latest.y)} ${_unit(s)}',
    week: i < 0 ? null : _signed(trend.last.y - trend[i].y, s),
    toGoal: goal == null ? null : _signed(goal - latest.y, s),
  );
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
  ChartWindow w,
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
  final dots = inWindow(all, (p) => p.x, w);
  final (from, to) = dataSpan(dots, w);
  return ChartSeries(
    dots: dots,
    line: dots,
    steps: bestSoFarSteps(all, w),
    gapDays: 42,
    from: from,
    to: to,
    formatY: axisFormat(current),
  );
}

/// "1 Apr–30 Apr" (år bara om perioden inte är i år).
String windowLabel(DateTime from, DateTime to, DateTime now) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String d(DateTime x) => '${x.day} ${m[x.month - 1]}${x.year == now.year ? '' : ' ${x.year}'}';
  return '${d(from)}–${d(to)}';
}

// ── valt intervall, per graf och enhet (bekvämlighet — får saknas) ──

/// Senast valda förvalda intervall. CUSTOM sparas inte (perioden är tillfällig).
Future<ChartRange> loadRange(String key, ChartRange fallback) async {
  try {
    final v = (await SharedPreferences.getInstance()).getString('chartRange.$key');
    return ChartRange.values.firstWhere((r) => r.name == v && r != ChartRange.custom, orElse: () => fallback);
  } catch (_) {
    return fallback;
  }
}

Future<void> saveRange(String key, ChartRange r) async {
  if (r == ChartRange.custom) return;
  try {
    await (await SharedPreferences.getInstance()).setString('chartRange.$key', r.name);
  } catch (_) {}
}
