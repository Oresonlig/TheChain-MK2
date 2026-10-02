/// KARANTÄN — skriver tillbaka till MK1:s state-JSON under övergången.
/// Beslut 2026-10-02: MK2 får BARA lägga till — avslutade pass, vilodagar och
/// kroppsvikt. Programmet, anteckningar och allt annat rörs aldrig; program-
/// ändringar görs på hemsidan tills den fryses.
///
/// Varje funktion tar MK1-JSON och returnerar en NY karta. Okända fält bevaras
/// orörda. `appVersion` skrivs ALDRIG (hemsidan laddar om sig om molnets version
/// är högre → oändlig loop).
library;

import 'dart:convert';

import '../domain/domain.dart';
import 'mk1_legacy.dart';

Map<String, Object?> _copy(Map<String, Object?> raw) =>
    (jsonDecode(jsonEncode(raw)) as Map).cast<String, Object?>();

const _measureNames = <Measure, String>{
  Measure.weight: 'weight',
  Measure.bodyweight: 'bw',
  Measure.repsOnly: 'bwreps',
  Measure.timed: 'timed',
  Measure.bodyweightTimed: 'bwtimed',
  Measure.cardio: 'cardio',
  Measure.cardioSprint: 'cardiosprint',
  Measure.run: 'run',
  Measure.runSprint: 'runsprint',
  Measure.carry: 'carry',
  Measure.inclineCardio: 'inclinecardio',
  Measure.sauna: 'sauna',
};

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// MK1:s fmtDate (toLocaleDateString en-GB weekday/month short) — "Thu 2 Oct".
String _mk1Date(DateTime t) => '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}';

Map<String, Object?> _set(SetEntry s) => {
      'sid': s.id.value,
      'warmup': s.kind == SetKind.warmup,
      if (s.values.weight != null) 'weight': s.values.weight,
      if (s.values.extra != null) 'extra': s.values.extra,
      if (s.values.reps != null) 'reps': s.values.reps,
      if (s.values.forcedReps != null) 'forced': s.values.forcedReps,
      if (s.values.secs != null) 'secs': s.values.secs,
      if (s.values.dist != null) 'dist': s.values.dist,
      if (s.values.distM != null) 'distm': s.values.distM,
      if (s.values.sprints != null) 'sprints': s.values.sprints,
      if (s.values.incline != null) 'incline': s.values.incline,
      if (s.values.temp != null) 'temp': s.values.temp,
      if (s.side != null) 'side': s.side == Side.left ? 'L' : 'R',
      if (s.bodyweightKg != null) 'bwSnap': s.bodyweightKg,
      // Mål (target) finns inte i MK1 och skrivs inte. MK1-fail sätts aldrig av MK2.
      if (s.excludeFromRecords) 'fail': true,
    };

/// MK1:s kedje-id:n i ordning (pass + vilodagar V, VB …), samma som buildEffectiveChain.
List<String> _chainIds(Map<String, Object?> raw) {
  final order = (raw['sessionOrder'] is List)
      ? (raw['sessionOrder'] as List).whereType<String>().where((id) => legacySession(id) != null).toList()
      : [...legacyDefaultSessionOrder];
  final rest = raw['restSlots'] is List
      ? (raw['restSlots'] as List).whereType<num>().map((n) => n.round()).toList()
      : [...legacyDefaultRestSlots];
  final ids = [...order];
  final sorted = [...rest]..sort((a, b) => b.compareTo(a));
  for (final (i, pos) in sorted.indexed) {
    ids.insert(pos.clamp(0, ids.length), i == 0 ? 'V' : 'V${String.fromCharCode(65 + i)}');
  }
  return ids;
}

/// Markerar [passId] klart i hemsidans pågående cykel. Är cykeln redan full
/// startas en ny först — samma som MK1:s doNewCycle.
void _markCycle(Map<String, Object?> raw, String passId, Map<String, Object?> entry, DateTime at) {
  final cycles = (raw['cycles'] is List) ? (raw['cycles'] as List) : <Object?>[];
  raw['cycles'] = cycles;
  final ids = _chainIds(raw);
  Map<String, Object?> newCycle() => <String, Object?>{
        'id': at.millisecondsSinceEpoch,
        'done': <String, Object?>{for (final id in ids) id: null},
      };
  if (cycles.isEmpty) cycles.add(newCycle());
  var cur = (cycles.last as Map).cast<String, Object?>();
  final done = (cur['done'] is Map) ? (cur['done'] as Map).cast<String, Object?>() : <String, Object?>{};
  final full = ids.isNotEmpty && ids.every((id) => done[id] != null);
  if (full) {
    cycles.add(newCycle());
    cur = (cycles.last as Map).cast<String, Object?>();
  }
  final d = (cur['done'] as Map).cast<String, Object?>();
  d[passId] = entry;
  cur['done'] = d;
  cycles[cycles.length - 1] = cur;
}

/// Lägger till ett avslutat MK2-pass i MK1:s historik + pågående cykel, och
/// uppdaterar MK1:s "förra gången"-antal så att hemsidan föreslår rätt antal set.
Map<String, Object?> appendWorkout(
  Map<String, Object?> raw,
  WorkoutEntry entry, {
  required String Function(ExerciseId) nameOf,
  required String sessionName,
}) {
  final w = entry.workout;
  final end = w.finishedAt;
  if (end == null) throw ArgumentError('Only finished workouts are written to MK1');
  final out = _copy(raw);
  final passId = w.sessionId.value;
  final exercises = <Map<String, Object?>>[];
  for (final (i, r) in w.exercises.indexed) {
    final rowId = r.slotId?.value ?? 'extra_${passId}_mk2_${end.millisecondsSinceEpoch}_$i';
    final name = nameOf(r.exerciseId);
    exercises.add(r.status == ExerciseStatus.skipped
        ? {'id': rowId, 'name': name, 'exId': r.exerciseId.value, 'skipped': true, if (r.isExtra) 'extra': true}
        : {
            'id': rowId,
            'name': name,
            'exId': r.exerciseId.value,
            'measure': _measureNames[r.measure],
            'sets': [for (final s in r.sets.where((s) => s.isLogged)) _set(s)],
            if (r.isExtra) 'extra': true,
          });
  }
  final duration = end.difference(w.startedAt).inMilliseconds;
  final ts = end.millisecondsSinceEpoch;
  final log = (out['log'] is List) ? out['log'] as List : <Object?>[];
  log.add({
    'passId': passId,
    'passName': sessionName,
    'timestamp': ts,
    'duration': duration > 0 ? duration : null,
    'exercises': exercises,
  });
  out['log'] = log;
  _markCycle(out, passId, {
    'date': _mk1Date(end),
    'timestamp': ts,
    'duration': duration > 0 ? duration : null,
    'exercises': exercises,
  }, end);

  final setCount = (out['lastSessionSetCount'] is Map)
      ? (out['lastSessionSetCount'] as Map).cast<String, Object?>()
      : <String, Object?>{};
  final warmCount = (out['lastSessionWarmupCount'] is Map)
      ? (out['lastSessionWarmupCount'] as Map).cast<String, Object?>()
      : <String, Object?>{};
  for (final r in w.exercises.where((r) => r.status != ExerciseStatus.skipped)) {
    final logged = r.sets.where((s) => s.isLogged);
    final work = logged.where((s) => s.kind == SetKind.work).length;
    if (work > 0) setCount[r.exerciseId.value] = work;
    warmCount[r.exerciseId.value] = logged.where((s) => s.kind == SetKind.warmup).length;
  }
  out['lastSessionSetCount'] = setCount;
  out['lastSessionWarmupCount'] = warmCount;
  out['updatedAt'] = ts;
  return out;
}

/// Markerar en vilodag klar i hemsidans pågående cykel (MK1 loggar vilodagar
/// bara där). Anteckningen följer inte med — MK1 har inget fält för den.
Map<String, Object?> appendRest(Map<String, Object?> raw, RestEntry entry) {
  final out = _copy(raw);
  final ts = entry.date.millisecondsSinceEpoch;
  _markCycle(out, entry.sessionId.value, {
    'date': _mk1Date(entry.date),
    'timestamp': ts,
    'rest': true,
    'exercises': <Object?>[],
  }, entry.date);
  out['updatedAt'] = ts;
  return out;
}

/// Lägger in eller uppdaterar dagens vikt. `ts` avgör vilken enhet som vinner
/// i hemsidans synk (MK1 3.92.1).
Map<String, Object?> upsertBodyweight(Map<String, Object?> raw, BodyweightEntry e, DateTime now) {
  final out = _copy(raw);
  final log = (out['weightLog'] is List) ? out['weightLog'] as List : <Object?>[];
  final ts = now.millisecondsSinceEpoch;
  final i = log.indexWhere((x) => x is Map && x['date'] == e.date);
  if (i >= 0) {
    final m = (log[i] as Map).cast<String, Object?>();
    m['weight'] = e.kg;
    m['ts'] = ts;
    log[i] = m;
  } else {
    log.add({'date': e.date, 'weight': e.kg, 'ts': ts});
  }
  out['weightLog'] = log;
  out['updatedAt'] = ts;
  return out;
}

/// Fälten MK2 aldrig får ändra (tester kontrollerar det).
const mk1ProtectedKeys = [
  'appVersion',
  'sessionOrder',
  'restSlots',
  'permanentSwaps',
  'exerciseOverrides',
  'addedExercises',
  'removedExercises',
  'hiddenRemoved',
  'exerciseOrder',
  'sessionNameOverrides',
  'customExercises',
  'exerciseTagOverrides',
  'exerciseMeasureOverride',
  'exerciseNotes',
  'deletions',
  'theme',
  'unit',
  'tempUnit',
];
