/// Operationer på ett pass. Rena funktioner: tar ett pass, returnerar ett nytt.
/// Seten ändras bara av användarens egna handlingar — ingen påfyllning eller
/// borttagning i bakgrunden (Gör om #4; sex set-vanish-fixar i MK1).
library;

import 'exercise.dart';
import 'history.dart';
import 'ids.dart';
import 'note.dart';
import 'program.dart';
import 'set_defaults.dart';
import 'set_entry.dart';
import 'workout.dart';

/// Ger nya unika id:n (UUID i appen, räknare i tester).
typedef IdGen = String Function();

/// Övningsuppslag med användarens justeringar redan applicerade.
typedef Catalogue = Exercise Function(ExerciseId id);

class WorkoutError implements Exception {
  const WorkoutError(this.message);
  final String message;
  @override
  String toString() => 'WorkoutError: $message';
}

List<SetEntry> _freshSets(Exercise e, Iterable<HistoryEntry> history, IdGen newId) {
  final c = defaultCounts(e, history);
  return [
    for (var i = 0; i < c.warmup; i++) SetEntry(id: SetId(newId()), kind: SetKind.warmup),
    for (var i = 0; i < c.work; i++) SetEntry(id: SetId(newId()), kind: SetKind.work),
  ];
}

WorkoutExercise _row(Exercise e, Iterable<HistoryEntry> history, IdGen newId, {SlotId? slot}) =>
    WorkoutExercise(
      id: newId(),
      exerciseId: e.id,
      measure: e.measure,
      slotId: slot,
      sets: _freshSets(e, history, newId),
    );

/// Startar ett pass från programmet. Vilodagar startas inte som pass — de
/// markeras klara med en [RestEntry].
Workout startWorkout(
  Session session,
  Catalogue catalogue,
  Iterable<HistoryEntry> history,
  DateTime now,
  IdGen newId,
) {
  if (session.isRest) throw const WorkoutError('Rest days are marked done, not started');
  return Workout(
    id: WorkoutId(newId()),
    sessionId: session.id,
    startedAt: now,
    exercises: [for (final s in session.slots) _row(catalogue(s.exerciseId), history, newId, slot: s.id)],
  );
}

Workout _mapRow(Workout w, String rowId, WorkoutExercise Function(WorkoutExercise) f) {
  if (w.isFinished) throw const WorkoutError('Workout is finished');
  var found = false;
  final rows = [
    for (final r in w.exercises)
      if (r.id == rowId) (() { found = true; return f(r); })() else r,
  ];
  if (!found) throw WorkoutError('No exercise row $rowId');
  return w.copyWith(exercises: rows);
}

Workout _mapSet(Workout w, String rowId, SetId setId, SetEntry Function(SetEntry) f) =>
    _mapRow(w, rowId, (r) {
      if (!r.sets.any((s) => s.id == setId)) throw WorkoutError('No set ${setId.value}');
      return r.copyWith(sets: [for (final s in r.sets) s.id == setId ? f(s) : s]);
    });

/// Skriver in värden. Ändrar inte loggstatus.
Workout setValues(Workout w, String rowId, SetId setId, SetValues values) =>
    _mapSet(w, rowId, setId, (s) => s.copyWith(values: values));

/// Sätter mål för ett set ("4 reps"). null tar bort målet OCH fail-markeringen.
Workout setTarget(Workout w, String rowId, SetId setId, SetValues? target) =>
    _mapSet(w, rowId, setId, (s) => s.withTarget(target));

/// FAIL på ett loggat set: på = missat (tomt mål tills användaren anger ett),
/// av = varken fail eller mål. Påverkar aldrig PR — den räknas på det utförda.
/// FAIL på ett loggat set låser upp det (siffror och mål kan rättas) och väntar
/// på LOG FAIL. FAIL av före låsning = vanligt set igen (Niklas 2026-10-03).
Workout setFailed(Workout w, String rowId, SetId setId, bool failed) {
  final marked = _mapSet(w, rowId, setId, (s) => s.withTarget(failed ? (s.target ?? SetValues.empty) : null));
  final s = marked.exercises.firstWhere((r) => r.id == rowId).sets.firstWhere((x) => x.id == setId);
  return failed && s.isLogged ? unlogSet(marked, rowId, setId) : marked;
}

/// L/R för unilaterala övningar: ingen sida → L → R → ingen sida.
Workout cycleSide(Workout w, String rowId, SetId setId) => _mapSet(w, rowId, setId, (s) {
      if (s.isLogged) throw const WorkoutError('Unlog the set before changing side');
      return s.withSide(switch (s.side) {
        null => Side.left,
        Side.left => Side.right,
        Side.right => null,
      });
    });

/// Loggar settet. [bodyweightKg] fångas för mätsätt med kroppsvikt.
Workout logSet(Workout w, String rowId, SetId setId, {double? bodyweightKg}) =>
    _mapSet(w, rowId, setId, (s) => s.copyWith(isLogged: true, bodyweightKg: bodyweightKg));

/// Låser upp ett loggat set. Värdena ligger kvar.
Workout unlogSet(Workout w, String rowId, SetId setId) =>
    _mapSet(w, rowId, setId, (s) => SetEntry(
          id: s.id,
          kind: s.kind,
          values: s.values,
          target: s.target,
          side: s.side,
          excludeFromRecords: s.excludeFromRecords,
        ));

/// Lägger till ett set. Uppvärmning hamnar efter sista uppvärmningen, arbete sist.
Workout addSet(Workout w, String rowId, SetKind kind, IdGen newId) => _mapRow(w, rowId, (r) {
      final s = SetEntry(id: SetId(newId()), kind: kind);
      if (kind == SetKind.work) return r.copyWith(sets: [...r.sets, s]);
      final lastWarm = r.sets.lastIndexWhere((x) => x.kind == SetKind.warmup);
      final at = lastWarm + 1;
      return r.copyWith(sets: [...r.sets.take(at), s, ...r.sets.skip(at)]);
    });

/// Tar bort ett set. Ett loggat set tas inte bort tyst — lås upp det först.
Workout removeSet(Workout w, String rowId, SetId setId) => _mapRow(w, rowId, (r) {
      final s = r.sets.where((x) => x.id == setId).firstOrNull;
      if (s == null) throw WorkoutError('No set ${setId.value}');
      if (s.isLogged) throw const WorkoutError('Unlog the set before removing it');
      return r.copyWith(sets: r.sets.where((x) => x.id != setId).toList());
    });

/// Tar bort sista ologgade set av sorten ("− WORK SET"). Loggade set rörs aldrig.
Workout removeLastUnlogged(Workout w, String rowId, SetKind kind) => _mapRow(w, rowId, (r) {
      final i = r.sets.lastIndexWhere((s) => s.kind == kind && !s.isLogged);
      if (i < 0) throw const WorkoutError('No unlogged set to remove');
      return r.copyWith(sets: [...r.sets.take(i), ...r.sets.skip(i + 1)]);
    });

/// Klar kräver att varje set är loggat och att det finns minst ett (Niklas
/// 2026-10-03). Vill man inte göra resten: ta bort seten eller SKIP.
Workout setStatus(Workout w, String rowId, ExerciseStatus status) => _mapRow(w, rowId, (r) {
      if (status == ExerciseStatus.done && !r.canMarkDone) {
        throw const WorkoutError('Log every set first — or remove the ones you skip');
      }
      return r.copyWith(status: status);
    });

/// Tillfälligt byte: bara det här passet. Programmet ändras inte. Nya set
/// skapas för den nya övningen; loggade set på raden blockerar bytet så att
/// inget loggat försvinner (MK1 3.22.1, 3.40.0).
Workout swapTemporarily(
  Workout w,
  String rowId,
  Exercise to,
  Iterable<HistoryEntry> history,
  IdGen newId,
) =>
    _mapRow(w, rowId, (r) {
      if (r.sets.any((s) => s.isLogged)) {
        throw const WorkoutError('Unlog the sets before swapping');
      }
      final original = r.temporarySwapFrom ?? r.exerciseId;
      return WorkoutExercise(
        id: r.id,
        exerciseId: to.id,
        measure: to.measure,
        slotId: r.slotId,
        temporarySwapFrom: to.id == original ? null : original,
        sets: _freshSets(to, history, newId),
      );
    });

/// Extraövning "bara idag".
Workout addExtra(Workout w, Exercise e, Iterable<HistoryEntry> history, IdGen newId) {
  if (w.isFinished) throw const WorkoutError('Workout is finished');
  return w.copyWith(exercises: [...w.exercises, _row(e, history, newId)]);
}

Workout removeExtra(Workout w, String rowId) {
  final r = w.exercises.where((x) => x.id == rowId).firstOrNull;
  if (r == null) throw WorkoutError('No exercise row $rowId');
  if (!r.isExtra) throw const WorkoutError('Only extras can be removed; skip program exercises');
  if (r.sets.any((s) => s.isLogged)) throw const WorkoutError('Unlog the sets before removing');
  return w.copyWith(exercises: w.exercises.where((x) => x.id != rowId).toList());
}

class FinishResult {
  const FinishResult(this.entry, this.notes);
  final WorkoutEntry entry;
  final List<ExerciseNote> notes;
}

/// Avslutar passet: alla rader måste vara gjorda eller överhoppade. Ej loggade
/// set följer inte med till historiken. Anteckningar arkiveras (note.dart).
FinishResult finishWorkout(Workout w, DateTime now, Iterable<ExerciseNote> notes) {
  if (w.isFinished) throw const WorkoutError('Workout is already finished');
  if (!w.canFinish) throw const WorkoutError('Every exercise must be done or skipped');
  final done = w.copyWith(
    finishedAt: now,
    exercises: [
      for (final r in w.exercises) r.copyWith(sets: r.sets.where((s) => s.isLogged).toList()),
    ],
  );
  return FinishResult(WorkoutEntry(workout: done), archiveAfterWorkout(notes, done));
}

/// Markerar en vilodag som klar.
RestEntry completeRest(Session session, DateTime now, {String? note}) {
  if (!session.isRest) throw const WorkoutError('Not a rest day');
  final text = note?.trim();
  return RestEntry(date: now, sessionId: session.id, note: (text == null || text.isEmpty) ? null : text);
}

/// Kortaste godtagbara anledning för att hoppa över ett pass ("x" duger inte).
const kMinSkipReason = 3;

/// Hoppar över ett pass. Vilodagen kan inte hoppas över — den är redan bara
/// en markering. Anledningen är obligatorisk.
SkippedEntry skippedEntry(Session session, DateTime now, String reason) {
  if (session.isRest) throw const WorkoutError('A forced rest day cannot be skipped');
  final text = reason.trim();
  if (text.length < kMinSkipReason) throw const WorkoutError('Write a reason for skipping');
  return SkippedEntry(date: now, sessionId: session.id, reason: text);
}
