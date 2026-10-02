/// KARANTÄN — läser MK1:s state-JSON (en `app_state.data`-rad) till MK2:s modell.
/// All kunskap om MK1:s format bor här och i mk1_legacy.dart; inget av det får
/// läcka in i lib/domain/. Raderas när sista användaren migrerats.
///
/// Beslut 2026-10-02: MK2 är HELT frikopplat från hemsidan. Det här är en
/// ENGÅNGSIMPORT per användare — MK2 skriver aldrig till MK1:s data (skrivdelen
/// mk1_writer raderades). Efter importen visar hemsidan en killswitch för kontot.
///
/// Status: UTKAST byggt mot MK1-koden och syntetiska exempel. Verifieras mot en
/// riktig (anonymiserad) backup innan det används mot molnet.
library;

import '../domain/domain.dart';
import 'mk1_legacy.dart';

/// Resultatet av en inläsning. [warnings] listar det som inte kunde tolkas —
/// tyst dataförlust är förbjuden.
class Mk1Snapshot {
  const Mk1Snapshot({
    required this.program,
    required this.history,
    required this.bodyweight,
    required this.custom,
    required this.overrides,
    required this.notes,
    required this.hiddenRecords,
    required this.manualRestarts,
    required this.mk1Round,
    required this.settings,
    required this.warnings,
  });

  final Program program;
  final List<HistoryEntry> history;
  final List<BodyweightEntry> bodyweight;
  final Map<ExerciseId, Exercise> custom;
  final Map<ExerciseId, ExerciseOverride> overrides;
  final List<ExerciseNote> notes;
  final Set<ExerciseId> hiddenRecords;

  /// Cykelstarter i MK1 (cycles[1..].id) — matas till chainState som omstarter.
  final List<DateTime> manualRestarts;

  /// MK1:s "Round N" (= antal cykler).
  final int mk1Round;
  final UserSettings settings;
  final List<String> warnings;

  /// roundOffset så att MK2:s härledda räknare visar samma runda som MK1.
  int roundOffsetFor(Program p) {
    final derived = chainState(p, history, manualRestarts: manualRestarts).round;
    return mk1Round - derived;
  }
}

// ── små läshjälpare (MK1-JSON är löst typad) ─────────────────────────────

double? _d(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
int? _i(Object? v) => v is num ? v.round() : (v is String ? int.tryParse(v) : null);
String? _s(Object? v) => v is String && v.isNotEmpty ? v : null;
Map<String, Object?> _m(Object? v) => v is Map ? v.cast<String, Object?>() : const {};
List<Object?> _l(Object? v) => v is List ? v.cast<Object?>() : const [];
DateTime? _ts(Object? v) {
  final ms = _i(v);
  return ms == null || ms <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

const _measureNames = <String, Measure>{
  'weight': Measure.weight,
  'bw': Measure.bodyweight,
  'bwreps': Measure.repsOnly,
  'timed': Measure.timed,
  'bwtimed': Measure.bodyweightTimed,
  'cardio': Measure.cardio,
  'cardiosprint': Measure.cardioSprint,
  'run': Measure.run,
  'runsprint': Measure.runSprint,
  'carry': Measure.carry,
  'inclinecardio': Measure.inclineCardio,
  'sauna': Measure.sauna,
};

const _groups = <String, MuscleGroup>{
  'Arms': MuscleGroup.arms,
  'Back': MuscleGroup.back,
  'Cardio': MuscleGroup.cardio,
  'Chest': MuscleGroup.chest,
  'Core': MuscleGroup.core,
  'Legs': MuscleGroup.legs,
  'Shoulders': MuscleGroup.shoulders,
  'Traps': MuscleGroup.traps,
};

Measure _flagsMeasure(Map<String, Object?> o) {
  final bw = o['bw'] == true, timed = o['timed'] == true;
  if (bw && timed) return Measure.bodyweightTimed;
  if (timed) return Measure.timed;
  if (bw) return Measure.bodyweight;
  return Measure.weight;
}

class _Decoder {
  _Decoder(this.raw);
  final Map<String, Object?> raw;
  final warnings = <String>[];
  late final Map<String, Exercise> customByName = {};
  final custom = <ExerciseId, Exercise>{};

  // ── övningar ──
  void readCustom() {
    for (final c in _l(raw['customExercises']).map(_m)) {
      final id = _s(c['id']), name = _s(c['name']);
      if (id == null || name == null) {
        warnings.add('customExercise without id/name skipped');
        continue;
      }
      final e = Exercise(
        id: ExerciseId(id),
        name: name,
        group: _groups[c['cat']] ?? MuscleGroup.other,
        measure: _measureNames[c['measure']] ?? _flagsMeasure(c),
        scheme: c['ramp'] == true ? SetScheme.ramp : (c['singles'] == true ? SetScheme.singles : SetScheme.standard),
        unilateral: c['uni'] == true,
        isCustom: true,
      );
      custom[e.id] = e;
      customByName[name] = e;
    }
  }

  /// MK1:s resolveExId: egen övning (via namn) → dess id, annars slug av kanoniskt namn.
  ExerciseId exIdForName(String name, [String? slotId]) {
    final c = customByName[name];
    if (c != null) return c.id;
    return exerciseIdFromName(legacyCanonicalName(name, slotId));
  }

  Measure measureFor(ExerciseId id, Map<String, Object?> row) {
    final own = _measureNames[row['measure']];
    if (own != null) return own;
    final ov = _measureNames[_m(raw['exerciseMeasureOverride'])[id.value]];
    if (ov != null) return ov;
    final known = custom[id] ?? libraryExercise(id);
    if (known != null) return known.measure;
    return _flagsMeasure(row);
  }

  // ── historik ──
  SetEntry readSet(Map<String, Object?> s, int i, String rowKey) => SetEntry(
        id: SetId(_s(s['sid']) ?? '$rowKey.s$i'),
        kind: s['warmup'] == true ? SetKind.warmup : SetKind.work,
        values: SetValues(
          weight: _d(s['weight']),
          extra: _d(s['extra']),
          reps: _i(s['reps']),
          forcedReps: _i(s['forced']),
          secs: _i(s['secs']),
          dist: _d(s['dist']),
          distM: _d(s['distm']),
          sprints: _i(s['sprints']),
          incline: _d(s['incline']),
          temp: _d(s['temp']),
        ),
        isLogged: true,
        // "Lagt kort ligger": MK1:s fail-set räknas inte i PR, precis som i MK1.
        excludeFromRecords: s['fail'] == true,
        side: switch (s['side']) { 'L' => Side.left, 'R' => Side.right, _ => null },
        bodyweightKg: _d(s['bwSnap']),
      );

  WorkoutExercise readRow(Map<String, Object?> ex, int i, String workoutKey) {
    final rowId = _s(ex['id']) ?? '$workoutKey.r$i';
    final name = _s(ex['name']) ?? 'Unknown exercise';
    // Gamla rader kan bära PLATSENS id som exId (K1, extra_E_0 …) — då löses
    // övningen upp via namnet i stället, så historiken hamnar på rätt övning
    // (hittat i Niklas riktiga backup 2026-10-02).
    final rawEx = _s(ex['exId']);
    final slotLike = rawEx != null && RegExp(r'^([A-Z]\d+|extra_.*|added_.*)$').hasMatch(rawEx);
    final exId = rawEx != null && !slotLike ? ExerciseId(rawEx) : exIdForName(name, rowId);
    final isExtra = rowId.startsWith('extra_') || ex['extra'] == true;
    final key = '$workoutKey.$rowId';
    return WorkoutExercise(
      id: key,
      exerciseId: exId,
      measure: measureFor(exId, ex),
      slotId: isExtra ? null : SlotId(rowId),
      status: ex['skipped'] == true ? ExerciseStatus.skipped : ExerciseStatus.done,
      sets: [for (final (j, s) in _l(ex['sets']).map(_m).indexed) readSet(s, j, key)],
    );
  }

  List<HistoryEntry> readHistory() {
    final out = <HistoryEntry>[];
    for (final (i, e) in _l(raw['log']).map(_m).indexed) {
      final end = _ts(e['timestamp']);
      final passId = _s(e['passId']);
      if (end == null || passId == null) {
        warnings.add('log[$i] without timestamp/passId skipped');
        continue;
      }
      final dur = _i(e['duration']);
      final key = 'mk1.${end.millisecondsSinceEpoch}.$passId';
      out.add(WorkoutEntry(
        workout: Workout(
          id: WorkoutId(key),
          sessionId: SessionId(passId),
          startedAt: dur != null && dur > 0 ? end.subtract(Duration(milliseconds: dur)) : end,
          finishedAt: end,
          exercises: [for (final (j, ex) in _l(e['exercises']).map(_m).indexed) readRow(ex, j, key)],
        ),
      ));
    }
    // Vilodagar loggas BARA i cycles[].done (aldrig i log).
    for (final c in _l(raw['cycles']).map(_m)) {
      for (final entry in _m(c['done']).entries) {
        final d = _m(entry.value);
        if (d['rest'] != true) continue;
        final at = _ts(d['timestamp']);
        if (at == null) {
          warnings.add('rest day ${entry.key} without timestamp skipped');
          continue;
        }
        out.add(RestEntry(date: at, sessionId: SessionId(entry.key)));
      }
    }
    return out;
  }

  // ── programmet ──
  /// MK1:s buildEffectiveChain: passordning + borttagna/tillagda/ordning + vilodagar.
  Program readProgram() {
    final order = _l(raw['sessionOrder']).whereType<String>().toList();
    final restRaw = raw['restSlots'];
    final rest = restRaw is List ? restRaw.map(_i).whereType<int>().toList() : legacyDefaultRestSlots;
    final removed = _m(raw['removedExercises']);
    final added = _m(raw['addedExercises']);
    final orderMap = _m(raw['exerciseOrder']);
    final swaps = _m(raw['permanentSwaps']);
    final renames = _m(raw['exerciseOverrides']);
    final names = _m(raw['sessionNameOverrides']);

    final sessions = <Session>[];
    for (final id in order.isEmpty ? legacyDefaultSessionOrder : order) {
      final base = legacySession(id);
      if (base == null) {
        warnings.add('session $id not in MK1 definitions skipped');
        continue;
      }
      final removedIds = _l(removed[id]).whereType<String>().toSet();
      final rows = <(String, String)>[
        for (final s in base.slots)
          if (!removedIds.contains(s.id)) (s.id, s.name),
        for (final a in _l(added[id]).map(_m))
          if (_s(a['id']) != null && _s(a['name']) != null) (_s(a['id'])!, _s(a['name'])!),
      ];
      final ord = _l(orderMap[id]).whereType<String>().toList();
      if (ord.isNotEmpty) {
        int rank(String sid) => ord.contains(sid) ? ord.indexOf(sid) : 1 << 20;
        final indexed = rows.indexed.toList()
          ..sort((x, y) {
            final c = rank(x.$2.$1).compareTo(rank(y.$2.$1));
            return c != 0 ? c : x.$1.compareTo(y.$1); // stabil som JS sort
          });
        rows
          ..clear()
          ..addAll(indexed.map((e) => e.$2));
      }
      final slots = <Slot>[
        for (final (slotId, baseName) in rows)
          () {
            final swap = _s(swaps[slotId]);
            final rename = _s(renames[slotId]);
            final current = swap ?? rename ?? baseName;
            final exId = exIdForName(current, slotId);
            final originalId = swap != null ? exIdForName(rename ?? baseName, slotId) : null;
            return Slot(
              id: SlotId(slotId),
              exerciseId: exId,
              originalExerciseId: originalId == exId ? null : originalId,
            );
          }(),
      ];
      sessions.add(Session(id: SessionId(id), name: _s(names[id]) ?? base.name, slots: slots));
    }
    // Vilodagar: samma insättning som MK1 (fallande position, id V, VB, VC …).
    final result = [...sessions];
    final sorted = [...rest]..sort((a, b) => b.compareTo(a));
    for (final (i, pos) in sorted.indexed) {
      final restId = i == 0 ? 'V' : 'V${String.fromCharCode(65 + i)}';
      result.insert(pos.clamp(0, result.length), Session(id: SessionId(restId), name: 'Rest', kind: SessionKind.rest));
    }
    return Program(sessions: result);
  }

  // ── justeringar ──
  Map<ExerciseId, ExerciseOverride> readOverrides(Program program) {
    final measure = <ExerciseId, Measure>{};
    for (final e in _m(raw['exerciseMeasureOverride']).entries) {
      final m = _measureNames[e.value];
      if (m != null) measure[ExerciseId(e.key)] = m;
    }
    final scheme = <ExerciseId, SetScheme>{};
    final uni = <ExerciseId, bool>{};
    // 1) Platsflaggor från MK1:s basprogram gäller övningen som står kvar på platsen.
    final swaps = _m(raw['permanentSwaps']);
    for (final s in program.sessions) {
      final base = legacySession(s.id.value);
      if (base == null) continue;
      for (final ls in base.slots) {
        if (swaps.containsKey(ls.id)) continue; // inswappad övning ärver inte platsens flaggor
        final slot = s.slots.where((x) => x.id.value == ls.id).firstOrNull;
        if (slot == null) continue;
        if (ls.ramp) scheme[slot.exerciseId] = SetScheme.ramp;
        if (ls.uni) uni[slot.exerciseId] = true;
      }
    }
    // 2) Användarens taggar (nycklade på exId sedan 3.76.0) vinner.
    for (final e in _m(raw['exerciseTagOverrides']).entries) {
      if (e.key.startsWith('extra_')) continue;
      final id = ExerciseId(e.key);
      final t = _m(e.value);
      if (t['singles'] == true) {
        scheme[id] = SetScheme.singles;
      } else if (t['ramp'] == true) {
        scheme[id] = SetScheme.ramp;
      } else if (t['ramp'] == false || t['singles'] == false) {
        scheme[id] = SetScheme.standard;
      }
      if (t['uni'] is bool) uni[id] = t['uni'] as bool;
    }
    final ids = {...measure.keys, ...scheme.keys, ...uni.keys};
    return {
      for (final id in ids) id: ExerciseOverride(measure: measure[id], scheme: scheme[id], unilateral: uni[id]),
    };
  }

  List<ExerciseNote> readNotes() => [
        for (final e in _m(raw['exerciseNotes']).entries)
          if (_s(e.value) != null)
            ExerciseNote(
              id: 'mk1.${e.key}',
              exerciseId: ExerciseId(e.key),
              text: _s(e.value)!,
              // MK1:s anteckningar var i praktiken permanenta — de blir nålade.
              pinned: true,
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
      ];

  Set<ExerciseId> readHidden() => {
        for (final n in _l(raw['ignoredPRs']).whereType<String>()) exIdForName(n),
      };

  List<BodyweightEntry> readBodyweight() => [
        for (final w in _l(raw['weightLog']).map(_m))
          if (_s(w['date']) != null && _d(w['weight']) != null)
            BodyweightEntry(date: _s(w['date'])!, kg: _d(w['weight'])!),
      ];

  UserSettings readSettings() => UserSettings(
        weightUnit: raw['unit'] == 'lbs' ? WeightUnit.lbs : WeightUnit.kg,
        tempUnit: raw['tempUnit'] == 'f' ? TempUnit.fahrenheit : TempUnit.celsius,
        restTimerEnabled: raw['timerEnabled'] == true,
        restTimerSecs: _i(raw['timerDefault']) ?? 120,
        weightGoalKg: raw['weightGoalEnabled'] == true ? _d(raw['weightGoal']) : null,
        ambientEffects: raw['ambientEffects'] != false,
      );
}

/// Läser en MK1-state (det som ligger i `app_state.data`).
Mk1Snapshot decodeMk1(Map<String, Object?> raw) {
  final d = _Decoder(raw)..readCustom();
  final program = d.readProgram();
  final cycles = _l(raw['cycles']).map(_m).toList();
  return Mk1Snapshot(
    program: program,
    history: d.readHistory(),
    bodyweight: d.readBodyweight(),
    custom: d.custom,
    overrides: d.readOverrides(program),
    notes: d.readNotes(),
    hiddenRecords: d.readHidden(),
    manualRestarts: [for (final c in cycles.skip(1)) ?_ts(c['id'])],
    mk1Round: cycles.isEmpty ? 1 : cycles.length,
    settings: d.readSettings(),
    warnings: d.warnings,
  );
}
