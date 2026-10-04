/// Domänmodellen ↔ JSON. Det här formatet lagras i Supabase-tabellernas `data`
/// och lokalt. Enums lagras med NAMN (inte index) så att ordningen i koden kan
/// ändras utan att gammal data feltolkas. `v` = formatversion per post.
library;

import '../domain/domain.dart';

const int kFormatVersion = 1;

typedef Json = Map<String, Object?>;

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

double? _d(Object? v) => v is num ? v.toDouble() : null;
int? _i(Object? v) => v is num ? v.toInt() : null;
DateTime? _t(Object? v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
List<Object?> _l(Object? v) => v is List ? v : const [];
Json _m(Object? v) => v is Map ? v.cast<String, Object?>() : const {};

// ── set ──
Json setValuesToJson(SetValues v) => {
      if (v.weight != null) 'weight': v.weight,
      if (v.extra != null) 'extra': v.extra,
      if (v.reps != null) 'reps': v.reps,
      if (v.forcedReps != null) 'forced': v.forcedReps,
      if (v.secs != null) 'secs': v.secs,
      if (v.dist != null) 'dist': v.dist,
      if (v.distM != null) 'distM': v.distM,
      if (v.sprints != null) 'sprints': v.sprints,
      if (v.incline != null) 'incline': v.incline,
      if (v.temp != null) 'temp': v.temp,
    };

SetValues setValuesFromJson(Json j) => SetValues(
      weight: _d(j['weight']),
      extra: _d(j['extra']),
      reps: _i(j['reps']),
      forcedReps: _i(j['forced']),
      secs: _i(j['secs']),
      dist: _d(j['dist']),
      distM: _d(j['distM']),
      sprints: _i(j['sprints']),
      incline: _d(j['incline']),
      temp: _d(j['temp']),
    );

Json setToJson(SetEntry s) => {
      'id': s.id.value,
      'kind': s.kind.name,
      'values': setValuesToJson(s.values),
      if (s.target != null) 'target': setValuesToJson(s.target!),
      if (s.isLogged) 'logged': true,
      if (s.excludeFromRecords) 'excluded': true,
      if (s.side != null) 'side': s.side!.name,
      if (s.bodyweightKg != null) 'bw': s.bodyweightKg,
    };

SetEntry setFromJson(Json j) => SetEntry(
      id: SetId(j['id'] as String),
      kind: _enum(SetKind.values, j['kind'], SetKind.work),
      values: setValuesFromJson(_m(j['values'])),
      target: j['target'] == null ? null : setValuesFromJson(_m(j['target'])),
      isLogged: j['logged'] == true,
      excludeFromRecords: j['excluded'] == true,
      side: j['side'] == null ? null : _enum(Side.values, j['side'], Side.left),
      bodyweightKg: _d(j['bw']),
    );

// ── pass ──
Json workoutToJson(Workout w) => {
      'v': kFormatVersion,
      'id': w.id.value,
      'session': w.sessionId.value,
      'sessionName': ?w.sessionName,
      'start': w.startedAt.millisecondsSinceEpoch,
      if (w.finishedAt != null) 'end': w.finishedAt!.millisecondsSinceEpoch,
      'exercises': [
        for (final e in w.exercises)
          {
            'id': e.id,
            'ex': e.exerciseId.value,
            'measure': e.measure.name,
            if (e.slotId != null) 'slot': e.slotId!.value,
            if (e.temporarySwapFrom != null) 'swapFrom': e.temporarySwapFrom!.value,
            'status': e.status.name,
            'sets': [for (final s in e.sets) setToJson(s)],
          },
      ],
    };

Workout workoutFromJson(Json j) => Workout(
      id: WorkoutId(j['id'] as String),
      sessionId: SessionId(j['session'] as String),
      sessionName: j['sessionName'] as String?,
      startedAt: _t(j['start'])!,
      finishedAt: _t(j['end']),
      exercises: [
        for (final e in _l(j['exercises']).map(_m))
          WorkoutExercise(
            id: e['id'] as String,
            exerciseId: ExerciseId(e['ex'] as String),
            measure: _enum(Measure.values, e['measure'], Measure.weight),
            slotId: e['slot'] == null ? null : SlotId(e['slot'] as String),
            temporarySwapFrom: e['swapFrom'] == null ? null : ExerciseId(e['swapFrom'] as String),
            status: _enum(ExerciseStatus.values, e['status'], ExerciseStatus.open),
            sets: [for (final s in _l(e['sets']).map(_m)) setFromJson(s)],
          ),
      ],
    );

/// Historikposter: avslutade pass och vilodagar delar tabellen mk2_workouts.
Json historyToJson(HistoryEntry h) => switch (h) {
      WorkoutEntry(:final workout, :final source) => {
          'type': 'workout',
          'source': source.name,
          'workout': workoutToJson(workout),
        },
      RestEntry(:final date, :final sessionId, :final note, :final source) => {
          'v': kFormatVersion,
          'type': 'rest',
          'source': source.name,
          'date': date.millisecondsSinceEpoch,
          'session': sessionId.value,
          'note': ?note,
        },
      SkippedEntry(:final date, :final sessionId, :final reason, :final sessionName, :final source) => {
          'v': kFormatVersion,
          'type': 'skip',
          'source': source.name,
          'date': date.millisecondsSinceEpoch,
          'session': sessionId.value,
          'sessionName': ?sessionName,
          'reason': reason,
        },
    };

HistoryEntry historyFromJson(Json j) {
  final source = _enum(EntrySource.values, j['source'], EntrySource.app);
  if (j['type'] == 'rest') {
    return RestEntry(date: _t(j['date'])!, sessionId: SessionId(j['session'] as String), note: j['note'] as String?);
  }
  if (j['type'] == 'skip') {
    return SkippedEntry(
      date: _t(j['date'])!,
      sessionId: SessionId(j['session'] as String),
      reason: j['reason'] as String? ?? '',
      sessionName: j['sessionName'] as String?,
    );
  }
  return WorkoutEntry(workout: workoutFromJson(_m(j['workout'])), source: source);
}

/// Historikposter som det här bygget känner till. En posttyp från ett NYARE
/// bygge (synkad från en annan enhet) hoppas över i stället för att krascha.
const _knownHistoryTypes = {null, 'workout', 'rest', 'skip'};

HistoryEntry? tryHistoryFromJson(Json j) => _knownHistoryTypes.contains(j['type']) ? historyFromJson(j) : null;

// ── program ──
Json programToJson(Program p) => {
      'v': kFormatVersion,
      'sessions': [
        for (final s in p.sessions)
          {
            'id': s.id.value,
            'name': s.name,
            'kind': s.kind.name,
            'slots': [
              for (final sl in s.slots) {'id': sl.id.value, 'ex': sl.exerciseId.value},
            ],
          },
      ],
    };

Program programFromJson(Json j) => Program(sessions: [
      for (final s in _l(j['sessions']).map(_m))
        Session(
          id: SessionId(s['id'] as String),
          name: s['name'] as String? ?? '',
          kind: _enum(SessionKind.values, s['kind'], SessionKind.training),
          slots: [
            // Äldre poster kan ha 'original' (permanent byte med minne, borttaget
            // 2026-10-04) — ignoreras.
            for (final sl in _l(s['slots']).map(_m)) Slot(id: SlotId(sl['id'] as String), exerciseId: ExerciseId(sl['ex'] as String)),
          ],
        ),
    ]);

// ── övrigt ──
Json bodyweightToJson(BodyweightEntry b) => {'v': kFormatVersion, 'date': b.date, 'kg': b.kg};
BodyweightEntry bodyweightFromJson(Json j) => BodyweightEntry(date: j['date'] as String, kg: _d(j['kg'])!);

Json noteToJson(ExerciseNote n) => {
      'v': kFormatVersion,
      'id': n.id,
      'ex': n.exerciseId.value,
      'text': n.text,
      'created': n.createdAt.millisecondsSinceEpoch,
      if (n.pinned) 'pinned': true,
      if (n.archivedAt != null) 'archivedAt': n.archivedAt!.millisecondsSinceEpoch,
      if (n.archivedIn != null) 'archivedIn': n.archivedIn!.value,
    };

ExerciseNote noteFromJson(Json j) => ExerciseNote(
      id: j['id'] as String,
      exerciseId: ExerciseId(j['ex'] as String),
      text: j['text'] as String? ?? '',
      createdAt: _t(j['created'])!,
      pinned: j['pinned'] == true,
      archivedAt: _t(j['archivedAt']),
      archivedIn: j['archivedIn'] == null ? null : WorkoutId(j['archivedIn'] as String),
    );

/// Egna övningar och justeringar delar tabellen mk2_exercises (`kind` skiljer).
Json customExerciseToJson(Exercise e) => {
      'v': kFormatVersion,
      'kind': 'custom',
      'id': e.id.value,
      'name': e.name,
      'group': e.group.name,
      'measure': e.measure.name,
      'scheme': e.scheme.name,
      if (e.unilateral) 'unilateral': true,
      if (e.tip != null) 'tip': e.tip,
      if (e.archived) 'archived': true,
    };

Exercise customExerciseFromJson(Json j) => Exercise(
      id: ExerciseId(j['id'] as String),
      name: j['name'] as String? ?? '',
      group: _enum(MuscleGroup.values, j['group'], MuscleGroup.other),
      measure: _enum(Measure.values, j['measure'], Measure.weight),
      scheme: _enum(SetScheme.values, j['scheme'], SetScheme.standard),
      unilateral: j['unilateral'] == true,
      tip: j['tip'] as String?,
      isCustom: true,
      archived: j['archived'] == true,
    );

Json overrideToJson(ExerciseId id, ExerciseOverride o) => {
      'v': kFormatVersion,
      'kind': 'override',
      'id': id.value,
      if (o.measure != null) 'measure': o.measure!.name,
      if (o.scheme != null) 'scheme': o.scheme!.name,
      if (o.unilateral != null) 'unilateral': o.unilateral,
    };

(ExerciseId, ExerciseOverride) overrideFromJson(Json j) => (
      ExerciseId(j['id'] as String),
      ExerciseOverride(
        measure: j['measure'] == null ? null : _enum(Measure.values, j['measure'], Measure.weight),
        scheme: j['scheme'] == null ? null : _enum(SetScheme.values, j['scheme'], SetScheme.standard),
        unilateral: j['unilateral'] as bool?,
      ),
    );

Json settingsToJson(UserSettings s) => {
      'v': kFormatVersion,
      'weightUnit': s.weightUnit.name,
      'tempUnit': s.tempUnit.name,
      'restTimer': s.restTimerEnabled,
      'restSecs': s.restTimerSecs,
      if (s.weightGoalKg != null) 'goalKg': s.weightGoalKg,
      'ambient': s.ambientEffects,
    };

UserSettings settingsFromJson(Json j) => UserSettings(
      weightUnit: _enum(WeightUnit.values, j['weightUnit'], WeightUnit.kg),
      tempUnit: _enum(TempUnit.values, j['tempUnit'], TempUnit.celsius),
      restTimerEnabled: j['restTimer'] == true,
      restTimerSecs: _i(j['restSecs']) ?? 120,
      weightGoalKg: _d(j['goalKg']),
      ambientEffects: j['ambient'] != false,
    );
