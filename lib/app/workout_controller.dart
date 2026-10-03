/// Ett pågående pass i UI:t. Kör domänens operationer (workout_ops.dart) och
/// sparar VARJE ändring lokalt direkt — passet överlever att appen stängs mitt
/// i, och synkas till andra enheter (beslut 2026-10-02).
library;

import 'package:flutter/foundation.dart';

import '../data/repository.dart';
import '../domain/domain.dart';

class WorkoutController extends ChangeNotifier {
  WorkoutController({
    required this.repo,
    required this.workout,
    required this.newId,
    required this.onFinished,
    this.onChanged,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
    expandedRowId = _firstOpen();
  }

  final Repository repo;
  final IdGen newId;
  final DateTime Function() _now;

  /// Anropas efter avslut (t.ex. synk + tillbaka till kedjan).
  final Future<void> Function() onFinished;

  /// Anropas efter varje sparad ändring (appen schemalägger en synk).
  final void Function()? onChanged;

  /// Passet avslutades eller kastades på en annan enhet — inga fler ändringar,
  /// annars skulle en sparning väcka det till liv igen.
  bool closedElsewhere = false;
  bool _disposed = false;

  /// Aktuellt läge. Ändras bara via metoderna nedan (som sparar direkt).
  Workout workout;

  /// Den expanderade övningen (en åt gången, som MK1:s V1 Collapse).
  String? expandedRowId;
  String? error;

  Exercise exerciseOf(WorkoutExercise r) =>
      repo.exercise(r.exerciseId) ??
      Exercise(id: r.exerciseId, name: r.exerciseId.value, group: MuscleGroup.other, measure: r.measure);

  Exercise _catalogue(ExerciseId id) =>
      repo.exercise(id) ?? Exercise(id: id, name: id.value, group: MuscleGroup.other, measure: Measure.weight);

  String? _firstOpen() {
    for (final r in workout.exercises) {
      if (r.status == ExerciseStatus.open) return r.id;
    }
    return null;
  }

  void _apply(Workout Function() op) {
    if (closedElsewhere) {
      error = _closedMessage;
      notifyListeners();
      return;
    }
    try {
      workout = op();
      error = null;
      repo.saveActiveWorkout(workout, _now());
      onChanged?.call();
    } on WorkoutError catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  static const _closedMessage = 'This session was finished or discarded on another device';

  /// Läser om passet efter en synk som ändrade lokal data (annan enhet).
  void reloadFromRepo() {
    if (_disposed || closedElsewhere || workout.isFinished) return;
    final fresh = repo.activeWorkouts().where((w) => w.id == workout.id).firstOrNull;
    if (fresh == null) {
      closedElsewhere = true;
      error = _closedMessage;
    } else {
      workout = fresh;
      if (!workout.exercises.any((r) => r.id == expandedRowId)) expandedRowId = _firstOpen();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void expand(String rowId) {
    expandedRowId = expandedRowId == rowId ? null : rowId;
    notifyListeners();
  }

  // ── set ──
  void setValues(String rowId, SetId setId, SetValues v) => _apply(() => setValuesOp(workout, rowId, setId, v));

  void setTarget(String rowId, SetId setId, SetValues? target) => _apply(() => setTargetOp(workout, rowId, setId, target));

  /// FAIL-knappen: på ett loggat set → upplåst och väntar på LOG FAIL (målet
  /// ligger kvar); på ett upplåst fail → vanligt set igen.
  void toggleFailed(String rowId, SetId setId) {
    final s = workout.exercises.firstWhere((x) => x.id == rowId).sets.firstWhere((x) => x.id == setId);
    _apply(() => setFailed(workout, rowId, setId, s.isLogged || s.target == null));
  }

  /// Loggar eller låser upp ett set. Kroppsvikt fångas för kroppsviktsmätsätt.
  void toggleLog(String rowId, SetId setId) {
    final r = workout.exercises.firstWhere((x) => x.id == rowId);
    final s = r.sets.firstWhere((x) => x.id == setId);
    if (s.isLogged) {
      _apply(() => unlogSet(workout, rowId, setId));
      return;
    }
    final bw = r.measure.usesBodyweight ? (repo.bodyweight().lastOrNull?.kg) : null;
    _apply(() => logSet(workout, rowId, setId, bodyweightKg: bw));
  }

  void cycleSide(String rowId, SetId setId) => _apply(() => cycleSideOp(workout, rowId, setId));

  void addSet(String rowId, SetKind kind) => _apply(() => addSetOp(workout, rowId, kind, newId));
  void removeSet(String rowId, SetId setId) => _apply(() => removeSetOp(workout, rowId, setId));
  void removeLastSet(String rowId, SetKind kind) => _apply(() => removeLastUnlogged(workout, rowId, kind));

  /// UI:t visar felet (snackbar) och kvitterar det här.
  String? takeError() {
    final e = error;
    error = null;
    return e;
  }

  // ── övningar ──
  void markDone(String rowId) {
    _apply(() => setStatus(workout, rowId, ExerciseStatus.done));
    expandedRowId = _firstOpen();
    notifyListeners();
  }

  void skip(String rowId) {
    _apply(() => setStatus(workout, rowId, ExerciseStatus.skipped));
    expandedRowId = _firstOpen();
    notifyListeners();
  }

  void reopen(String rowId) {
    _apply(() => setStatus(workout, rowId, ExerciseStatus.open));
    expandedRowId = rowId;
    notifyListeners();
  }

  void swapTemporarily(String rowId, ExerciseId to) =>
      _apply(() => swapTemporarilyOp(workout, rowId, _catalogue(to), repo.history(), newId));

  /// Permanent byte: ändrar programmet och byter även i det här passet.
  Future<void> swapPermanently(String rowId, ExerciseId to) async {
    final r = workout.exercises.firstWhere((x) => x.id == rowId);
    final slot = r.slotId;
    if (slot == null) {
      error = 'Extras are swapped by removing and adding';
      notifyListeners();
      return;
    }
    swapTemporarily(rowId, to);
    if (error != null) return;
    final p = swapPermanentlyOp(repo.program(), workout.sessionId, slot, to);
    await repo.saveProgram(p, _now());
    // I passet är det nu programmets övning, inte ett tillfälligt byte.
    _apply(() => workout.copyWith(exercises: [
          for (final x in workout.exercises)
            x.id != rowId
                ? x
                : WorkoutExercise(id: x.id, exerciseId: x.exerciseId, measure: x.measure, slotId: x.slotId, status: x.status, sets: x.sets),
        ]));
  }

  void addExtra(ExerciseId id) {
    _apply(() => addExtraOp(workout, _catalogue(id), repo.history(), newId));
    expandedRowId = workout.exercises.last.id;
    notifyListeners();
  }

  void removeExtra(String rowId) => _apply(() => removeExtraOp(workout, rowId));

  // ── anteckningar ──
  List<ExerciseNote> notesFor(ExerciseId id) => activeNotes(repo.notes(), id).toList();

  Future<void> addNote(ExerciseId id, String text, {bool pinned = false}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await repo.saveNote(ExerciseNote(id: newId(), exerciseId: id, text: t, createdAt: _now(), pinned: pinned), _now());
    onChanged?.call();
    notifyListeners();
  }

  Future<void> deleteNote(ExerciseNote n) async {
    await repo.deleteNote(n.id, _now());
    onChanged?.call();
    notifyListeners();
  }

  // ── avsluta ──
  bool get canFinish => workout.canFinish;

  Future<bool> finish() async {
    if (closedElsewhere) {
      error = _closedMessage;
      notifyListeners();
      return false;
    }
    try {
      final res = finishWorkout(workout, _now(), repo.notes());
      await repo.saveHistory(res.entry, _now());
      for (final n in res.notes) {
        await repo.saveNote(n, _now());
      }
      workout = res.entry.workout;
      notifyListeners();
      await onFinished();
      return true;
    } on WorkoutError catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> discard() async {
    if (!closedElsewhere) await repo.discardActiveWorkout(workout, _now());
    await onFinished();
  }
}

// Namnen på domänens operationer krockar med metoderna ovan — alias här.
Workout setValuesOp(Workout w, String r, SetId s, SetValues v) => setValues(w, r, s, v);
Workout setTargetOp(Workout w, String r, SetId s, SetValues? t) => setTarget(w, r, s, t);
Workout cycleSideOp(Workout w, String r, SetId s) => cycleSide(w, r, s);
Workout addSetOp(Workout w, String r, SetKind k, IdGen g) => addSet(w, r, k, g);
Workout removeSetOp(Workout w, String r, SetId s) => removeSet(w, r, s);
Workout swapTemporarilyOp(Workout w, String r, Exercise to, Iterable<HistoryEntry> h, IdGen g) =>
    swapTemporarily(w, r, to, h, g);
Program swapPermanentlyOp(Program p, SessionId s, SlotId slot, ExerciseId to) => swapPermanently(p, s, slot, to);
Workout addExtraOp(Workout w, Exercise e, Iterable<HistoryEntry> h, IdGen g) => addExtra(w, e, h, g);
Workout removeExtraOp(Workout w, String r) => removeExtra(w, r);
