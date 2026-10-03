/// Fält i UI:t: etikett, visningsvärde och tolkning av inmatning. Allt lagras
/// metriskt (kg, sekunder, km, m, °C); enhetsinställningen styr bara visningen.
library;

import '../domain/domain.dart';

const _lbsPerKg = 2.20462;

String _num(num v) {
  final d = v.toDouble();
  return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(d * 10 == (d * 10).roundToDouble() ? 1 : 2);
}

/// Ett inmatningsfält för ett mätsätt (inkl. +F där det är meningsfullt).
enum InputField { weight, extra, reps, forced, secs, dist, distM, sprints, incline, temp }

List<InputField> inputFields(Measure m) => [
      for (final f in m.fields)
        switch (f) {
          SetField.weight => InputField.weight,
          SetField.extra => InputField.extra,
          SetField.reps => InputField.reps,
          SetField.secs => InputField.secs,
          SetField.dist => InputField.dist,
          SetField.distM => InputField.distM,
          SetField.sprints => InputField.sprints,
          SetField.incline => InputField.incline,
          SetField.temp => InputField.temp,
        },
      if (m.forcedReps) InputField.forced,
    ];

String fieldLabel(InputField f, Measure m, UserSettings s) => switch (f) {
      InputField.weight => s.weightUnit == WeightUnit.lbs ? 'LBS' : 'KG',
      InputField.extra => s.weightUnit == WeightUnit.lbs ? '+ LBS' : '+ KG',
      InputField.reps => 'REPS',
      InputField.forced => '+F',
      InputField.secs => m.minutesInput ? 'MIN' : 'SEC',
      InputField.dist => 'KM',
      InputField.distM => 'M',
      InputField.sprints => 'SPRINTS',
      InputField.incline => '%',
      InputField.temp => s.tempUnit == TempUnit.fahrenheit ? '°F' : '°C',
    };

/// Lagrat värde → text i fältet.
String displayValue(InputField f, SetValues v, Measure m, UserSettings s) {
  num? raw = switch (f) {
    InputField.weight => v.weight,
    InputField.extra => v.extra,
    InputField.reps => v.reps,
    InputField.forced => v.forcedReps,
    InputField.secs => v.secs,
    InputField.dist => v.dist,
    InputField.distM => v.distM,
    InputField.sprints => v.sprints,
    InputField.incline => v.incline,
    InputField.temp => v.temp,
  };
  if (raw == null) return '';
  if ((f == InputField.weight || f == InputField.extra) && s.weightUnit == WeightUnit.lbs) raw = raw * _lbsPerKg;
  if (f == InputField.secs && m.minutesInput) raw = raw / 60;
  if (f == InputField.temp && s.tempUnit == TempUnit.fahrenheit) raw = raw * 9 / 5 + 32;
  return _num(raw);
}

/// Text i fältet → nya värden (tomt fält = null).
SetValues applyInput(InputField f, String text, SetValues v, Measure m, UserSettings s) {
  final t = text.trim().replaceAll(',', '.');
  double? d = t.isEmpty ? null : double.tryParse(t);
  if (d != null && (f == InputField.weight || f == InputField.extra) && s.weightUnit == WeightUnit.lbs) d = d / _lbsPerKg;
  if (d != null && f == InputField.secs && m.minutesInput) d = d * 60;
  if (d != null && f == InputField.temp && s.tempUnit == TempUnit.fahrenheit) d = (d - 32) * 5 / 9;
  final i = d?.round();
  return SetValues(
    weight: f == InputField.weight ? d : v.weight,
    extra: f == InputField.extra ? d : v.extra,
    reps: f == InputField.reps ? i : v.reps,
    forcedReps: f == InputField.forced ? i : v.forcedReps,
    secs: f == InputField.secs ? i : v.secs,
    dist: f == InputField.dist ? d : v.dist,
    distM: f == InputField.distM ? d : v.distM,
    sprints: f == InputField.sprints ? i : v.sprints,
    incline: f == InputField.incline ? d : v.incline,
    temp: f == InputField.temp ? d : v.temp,
  );
}

String measureDescription(Measure m) => switch (m) {
      Measure.weight => 'Weight × reps',
      Measure.bodyweight => 'Bodyweight + added load',
      Measure.repsOnly => 'Reps',
      Measure.timed => 'Time',
      Measure.bodyweightTimed => 'Bodyweight + added load · time',
      Measure.cardio => 'Time + distance',
      Measure.cardioSprint => 'Time · sprints · distance',
      Measure.run => 'Run · pace is the record',
      Measure.runSprint => 'Run with sprints · pace is the record',
      Measure.carry => 'Weight + distance',
      Measure.inclineCardio => 'Incline · time · distance',
      Measure.sauna => 'Temperature + time',
    };

String _w(double kg, UserSettings s) =>
    s.weightUnit == WeightUnit.lbs ? '${_num(kg * _lbsPerKg)} lbs' : '${_num(kg)} kg';

/// Ett set på en rad ("100 kg × 5 +1", "BW + 10 kg · 60 s", "100 kg × 3/4 ✗").
/// ✗ = FAIL (eller MK1:s gamla fail) — samma markering överallt.
String fmtSet(SetEntry set, Measure m, UserSettings s) {
  final line = _fmtValues(set, m, s);
  return set.missed(m) || set.excludeFromRecords ? '$line ✗' : line;
}

String _fmtValues(SetEntry set, Measure m, UserSettings s) {
  final v = set.values;
  String reps() {
    if (v.reps == null) return '';
    final goal = set.target?.reps;
    final r = goal != null && goal != v.reps ? '${v.reps}/$goal' : '${v.reps}';
    return v.forcedReps != null && v.forcedReps! > 0 ? '$r +${v.forcedReps}' : r;
  }

  String time() {
    if (v.secs == null) return '';
    final t = m.minutesInput ? '${_num(v.secs! / 60)} min' : '${v.secs} s';
    final goal = set.target?.secs;
    return goal != null && goal != v.secs ? '$t / ${m.minutesInput ? '${_num(goal / 60)} min' : '$goal s'}' : t;
  }

  final parts = switch (m) {
    Measure.weight => [if (v.weight != null) _w(v.weight!, s), if (reps().isNotEmpty) '× ${reps()}'],
    Measure.bodyweight => ['BW + ${_w(v.extra ?? 0, s)}', if (reps().isNotEmpty) '× ${reps()}'],
    Measure.repsOnly => [if (reps().isNotEmpty) '${reps()} reps'],
    Measure.timed => [time()],
    Measure.bodyweightTimed => ['BW + ${_w(v.extra ?? 0, s)}', '· ${time()}'],
    Measure.carry => [if (v.weight != null) _w(v.weight!, s), if (v.distM != null) '· ${_num(v.distM!)} m'],
    Measure.sauna => [
        if (v.temp != null) s.tempUnit == TempUnit.fahrenheit ? '${_num(v.temp! * 9 / 5 + 32)} °F' : '${_num(v.temp!)} °C',
        if (v.secs != null) '· ${time()}',
      ],
    Measure.inclineCardio => [
        if (v.incline != null) '${_num(v.incline!)}%',
        if (v.secs != null) '· ${time()}',
        if (v.dist != null) '· ${_num(v.dist!)} km',
      ],
    Measure.cardio || Measure.run || Measure.cardioSprint || Measure.runSprint => [
        if (v.secs != null) time(),
        if (v.sprints != null) '· ${v.sprints} sprints',
        if (v.dist != null) '· ${_num(v.dist!)} km',
      ],
  };
  return parts.where((p) => p.isNotEmpty).join(' ').replaceFirst(RegExp(r'^· '), '');
}

String daysAgo(DateTime then, DateTime now) {
  final d = DateTime(now.year, now.month, now.day).difference(DateTime(then.year, then.month, then.day)).inDays;
  return d <= 0 ? 'today' : d == 1 ? 'yesterday' : '${d}d ago';
}
