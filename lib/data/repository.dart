/// Det typade lagret appen pratar med: domänobjekt in och ut, synkmotorn under.
/// Plus engångsimporten från MK1 (beslut 2026-10-02).
library;

import '../domain/domain.dart';
import '../mk1/mk1_codec.dart';
import 'json_codec.dart';
import 'sync_engine.dart';

const _programId = 'program';
const _settingsId = 'settings';

/// Kedjans metadata från MK1 (omstarter + rundans startvärde).
class ChainMeta {
  const ChainMeta({this.restarts = const [], this.roundOffset = 0});
  final List<DateTime> restarts;
  final int roundOffset;
}

class Repository {
  Repository(this.engine);

  final SyncEngine engine;

  TableSync get _w => engine[Tables.workouts];

  /// Avkodade värden per tabellversion. Varje skärm läser historik, program och
  /// övningar många gånger per ombyggnad (kedjan, PR, "förra gången" per rad) —
  /// utan cache avkodades alla pass från JSON vid varje läsning. Värdena är
  /// oföränderliga, så en cachad lista kan delas.
  final _memo = <String, (String, Object?)>{};

  T _cached<T>(String key, List<String> tables, T Function() build) {
    final v = [for (final t in tables) engine[t].version].join('.');
    final hit = _memo[key];
    if (hit != null && hit.$1 == v) return hit.$2 as T;
    final value = build();
    _memo[key] = (v, value);
    return value;
  }

  List<HistoryEntry> _allEntries() => _cached('entries', const [Tables.workouts], () => List.unmodifiable([
        for (final j in _w.liveValues) ?tryHistoryFromJson(j),
      ]));

  // ── läsning ──
  /// Avslutade pass och vilodagar. Pågående pass räknas inte (PR, kedja, "förra gången").
  List<HistoryEntry> history() => _cached('history', const [Tables.workouts], () => List.unmodifiable([
        for (final h in _allEntries())
          if (h is! WorkoutEntry || h.workout.isFinished) h,
      ]));

  /// Pågående pass (synkas mellan enheter, beslut 2026-10-02). Normalt högst ett.
  List<Workout> activeWorkouts() => _cached('active', const [Tables.workouts], () => List.unmodifiable([
        for (final h in _allEntries())
          if (h case WorkoutEntry(:final workout) when !workout.isFinished) workout,
      ]));

  Workout? activeWorkoutFor(SessionId id) {
    for (final w in activeWorkouts()) {
      if (w.sessionId == id) return w;
    }
    return null;
  }

  Program program() => _cached('program', const [Tables.program], () {
        final j = engine[Tables.program].items[_programId];
        if (j == null || j.isDeleted) return const Program(sessions: []);
        return programFromJson(_sub(j.value!, 'program'));
      });

  ChainMeta chainMeta() => _cached('chainMeta', const [Tables.program], () {
        final j = engine[Tables.program].items[_programId];
        if (j == null || j.isDeleted) return const ChainMeta();
        final c = _sub(j.value!, 'chain');
        return ChainMeta(
          restarts: [for (final ms in (c['restarts'] as List?) ?? const []) DateTime.fromMillisecondsSinceEpoch((ms as num).toInt())],
          roundOffset: (c['roundOffset'] as num?)?.toInt() ?? 0,
        );
      });

  ChainState chain() => _cached('chain', const [Tables.program, Tables.workouts], () {
        final m = chainMeta();
        return chainState(program(), history(), manualRestarts: m.restarts, roundOffset: m.roundOffset);
      });

  List<BodyweightEntry> bodyweight() => _cached('bodyweight', const [Tables.bodyweight], () {
        final list = <BodyweightEntry>[for (final j in engine[Tables.bodyweight].liveValues) bodyweightFromJson(j)]
          ..sort((a, b) => a.date.compareTo(b.date));
        return List<BodyweightEntry>.unmodifiable(list);
      });

  List<ExerciseNote> notes() =>
      _cached('notes', const [Tables.notes], () => List.unmodifiable([for (final j in engine[Tables.notes].liveValues) noteFromJson(j)]));

  Map<ExerciseId, Exercise> customExercises() => _cached(
      'custom',
      const [Tables.exercises],
      () => Map.unmodifiable({
            for (final j in engine[Tables.exercises].liveValues)
              if (j['kind'] == 'custom') ExerciseId(j['id'] as String): customExerciseFromJson(j),
          }));

  Map<ExerciseId, ExerciseOverride> overrides() => _cached(
      'overrides',
      const [Tables.exercises],
      () => Map.unmodifiable({
            for (final j in engine[Tables.exercises].liveValues)
              if (j['kind'] == 'override') overrideFromJson(j).$1: overrideFromJson(j).$2,
          }));

  UserSettings settings() => _cached('settings', const [Tables.settings], () {
        final j = engine[Tables.settings].items[_settingsId];
        return (j == null || j.isDeleted) ? const UserSettings() : settingsFromJson(j.value!);
      });

  Exercise? exercise(ExerciseId id) => resolveExercise(id, custom: customExercises(), overrides: overrides());

  /// PR per övning, räknat på övningens NUVARANDE mätsätt (records.dart). Inga
  /// dolda rekord (Niklas 2026-10-05: "inga PR borde vara dolda").
  Map<ExerciseId, PersonalRecord> records() => _cached('records', const [Tables.workouts, Tables.exercises], () {
        final custom = customExercises(), over = overrides();
        return Map.unmodifiable(personalRecords(
          history(),
          measureOf: (id) => resolveExercise(id, custom: custom, overrides: over)?.measure,
        ));
      });

  /// Namnet en historikpost visas med: postens eget (lagt kort ligger), annars
  /// programmets nuvarande, annars ett neutralt "Session" (borttaget pass).
  String sessionNameOf(HistoryEntry e, [Program? p]) {
    final (id, stored) = switch (e) {
      WorkoutEntry(:final workout) => (workout.sessionId, workout.sessionName),
      SkippedEntry(:final sessionId, :final sessionName) => (sessionId, sessionName),
      RestEntry(:final sessionId) => (sessionId, 'Forced rest day'),
    };
    return stored ?? (p ?? program()).sessionById(id)?.name ?? 'Session';
  }

  // ── skrivning ──

  /// Engångsifyllnad (2026-10-04): poster från före Workout.sessionName får
  /// passets namn som det är NU, en gång. Därefter ändras de aldrig — ett
  /// omdöpt eller borttaget pass skriver inte om historiken. Pågående pass
  /// hoppas över (passvyn håller egen kopia; namnet sätts vid avslut).
  /// Returnerar antalet uppdaterade poster.
  Future<int> backfillSessionNames(DateTime now) async {
    final p = program();
    final todo = <HistoryEntry>[];
    for (final j in _w.liveValues.toList()) {
      final h = tryHistoryFromJson(j);
      final named = switch (h) {
        WorkoutEntry(:final workout) when workout.isFinished && workout.sessionName == null =>
          p.sessionById(workout.sessionId) == null
              ? null
              : WorkoutEntry(workout: workout.copyWith(sessionName: p.sessionById(workout.sessionId)!.name), source: h.source),
        SkippedEntry(:final sessionId, :final sessionName) when sessionName == null => p.sessionById(sessionId) == null
            ? null
            : SkippedEntry(
                date: h.date,
                sessionId: sessionId,
                reason: h.reason,
                sessionName: p.sessionById(sessionId)!.name,
                source: h.source,
              ),
        _ => null,
      };
      if (named != null) todo.add(named);
    }
    for (final h in todo) {
      await saveHistory(h, now);
    }
    return todo.length;
  }

  static String historyId(HistoryEntry h) => switch (h) {
        WorkoutEntry(:final workout) => workout.id.value,
        RestEntry(:final sessionId, :final date) => 'rest.${sessionId.value}.${date.millisecondsSinceEpoch}',
        SkippedEntry(:final sessionId, :final date) => 'skip.${sessionId.value}.${date.millisecondsSinceEpoch}',
      };

  Future<void> saveHistory(HistoryEntry h, DateTime now) => _w.put(historyId(h), historyToJson(h), now);

  /// Sparar ett pågående pass (varje ändring). Samma id som när det avslutas,
  /// så det avslutade passet ersätter det pågående.
  Future<void> saveActiveWorkout(Workout w, DateTime now) => saveHistory(WorkoutEntry(workout: w), now);

  /// Avbryter ett pågående pass (raderas överallt).
  Future<void> discardActiveWorkout(Workout w, DateTime now) => _w.remove(w.id.value, now);
  Future<void> deleteHistory(HistoryEntry h, DateTime now) => _w.remove(historyId(h), now);

  Future<void> saveProgram(Program p, DateTime now, {ChainMeta? meta}) {
    final m = meta ?? chainMeta();
    return engine[Tables.program].put(_programId, {
      'program': programToJson(p),
      'chain': {
        'restarts': [for (final d in m.restarts) d.millisecondsSinceEpoch],
        'roundOffset': m.roundOffset,
      },
    }, now);
  }

  Future<void> saveBodyweight(BodyweightEntry b, DateTime now) =>
      engine[Tables.bodyweight].put(b.date, bodyweightToJson(b), now);
  Future<void> deleteBodyweight(String date, DateTime now) => engine[Tables.bodyweight].remove(date, now);

  Future<void> saveNote(ExerciseNote n, DateTime now) => engine[Tables.notes].put(n.id, noteToJson(n), now);
  Future<void> deleteNote(String id, DateTime now) => engine[Tables.notes].remove(id, now);

  Future<void> saveCustomExercise(Exercise e, DateTime now) =>
      engine[Tables.exercises].put('custom:${e.id.value}', customExerciseToJson(e), now);
  Future<void> saveOverride(ExerciseId id, ExerciseOverride o, DateTime now) =>
      engine[Tables.exercises].put('override:${id.value}', overrideToJson(id, o), now);

  /// Äldre poster kan ha 'hiddenRecords' (MK1:s ignoredPRs, borttaget
  /// 2026-10-05) — läses inte och skrivs inte längre.
  Future<void> saveSettings(UserSettings s, DateTime now) => engine[Tables.settings].put(_settingsId, settingsToJson(s), now);

  /// Engångsimport från MK1. Under testfasen kan den köras om (MK2-ändringar
  /// skrivs då över). Killswitch-markeringen sätts INTE här — det görs vid den
  /// riktiga övergången efter F3.
  /// [keepProgram]: appen har redan ett eget program som användaren vill
  /// behålla (Niklas 2026-10-05) — då tas bara historik, PR, vikt och
  /// anteckningar in; programmet och kedjans räknare lämnas orörda.
  Future<void> importMk1(Mk1Snapshot s, DateTime now, {bool keepProgram = false}) async {
    if (!keepProgram) {
      await saveProgram(s.program, now,
          meta: ChainMeta(restarts: s.manualRestarts, roundOffset: s.roundOffsetFor(s.program)));
    }
    // En diskskrivning per tabell (114 pass skrev annars hela tabellen 114 gånger).
    await _w.putAll({for (final h in s.history) historyId(h): historyToJson(h)}, now);
    await engine[Tables.bodyweight].putAll({for (final b in s.bodyweight) b.date: bodyweightToJson(b)}, now);
    await engine[Tables.notes].putAll({for (final n in s.notes) n.id: noteToJson(n)}, now);
    await engine[Tables.exercises].putAll({
      for (final e in s.custom.values) 'custom:${e.id.value}': customExerciseToJson(e),
      for (final o in s.overrides.entries) 'override:${o.key.value}': overrideToJson(o.key, o.value),
    }, now);
    // Bara det hemsidan själv har; appens egna val (rundturen, larmets
    // helskärm, anteckning vid avslut, bygget) ligger kvar.
    final w = s.settings;
    await saveSettings(
      settings().copyWith(
        weightUnit: w.weightUnit,
        tempUnit: w.tempUnit,
        restTimerEnabled: w.restTimerEnabled,
        restTimerSecs: w.restTimerSecs,
        weightGoalKg: w.weightGoalKg,
        clearGoal: w.weightGoalKg == null,
        ambientEffects: w.ambientEffects,
        importedFromWebsite: true,
      ),
      now,
    );
  }
}

Json _sub(Json j, String key) => (j[key] as Map?)?.cast<String, Object?>() ?? const {};
