/// Visningsformat. Allt lagras metriskt; enheterna styr bara texten.
library;

import '../domain/domain.dart';

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String fmtWeight(double kg, WeightUnit u) =>
    u == WeightUnit.lbs ? '${_num(kg * 2.20462)} lbs' : '${_num(kg)} kg';

String fmtPace(double kmh) {
  if (kmh <= 0 || !kmh.isFinite) return '—';
  final secPerKm = 3600 / kmh;
  var m = secPerKm ~/ 60;
  var s = (secPerKm % 60).round();
  if (s == 60) {
    m++;
    s = 0;
  }
  return '$m:${s.toString().padLeft(2, '0')} /km';
}

/// PR-värdet i läsbar form.
String fmtRecord(PersonalRecord pr, WeightUnit u) {
  final v = pr.set.values;
  return switch (pr.measure.pr) {
    PrMetric.weight => '${fmtWeight(pr.value, u)}${v.reps != null ? ' × ${v.reps}' : ''}',
    PrMetric.extra => 'BW + ${fmtWeight(v.extra ?? 0, u)}${v.reps != null ? ' × ${v.reps}' : ''}',
    PrMetric.reps => '${pr.value.round()} reps',
    PrMetric.secs => pr.measure.minutesInput ? '${_num(pr.value / 60)} min' : '${pr.value.round()} s',
    PrMetric.dist => '${_num(pr.value)} km',
    PrMetric.sprints => '${pr.value.round()} sprints',
    PrMetric.pace => fmtPace(pr.value),
  };
}

String fmtDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}
