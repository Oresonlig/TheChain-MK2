/// Appens tillstånd: inloggning, synk och import. UI:t lyssnar på den här.
/// Allt mot Supabase går via [Backend] så att UI och logik kan testas utan nät.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/repository.dart';
import '../data/sync_engine.dart';
import '../domain/domain.dart';
import '../mk1/mk1_codec.dart';
import 'updater.dart';
import 'workout_controller.dart';

/// Det appen behöver av servern (Supabase i appen, fake i tester).
abstract class Backend {
  String? get userId;
  String? get userEmail;
  Stream<String?> get userChanges;
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Remote get remote;
  Future<LocalStore> localStoreFor(String userId);
  Future<String> deviceId();

  /// MK1:s rad (app_state.data) för engångsimporten. Bara läsning.
  Future<Map<String, Object?>?> fetchMk1State();
}

enum Phase { signedOut, loading, ready }

class AppController extends ChangeNotifier {
  AppController(this.backend, {DateTime Function()? clock, this.updater}) : _now = clock ?? DateTime.now;

  final Backend backend;

  /// Självuppdatering (null i tester och lokala byggen).
  final Updater? updater;
  UpdateInfo? update;
  String? updateStatus;
  final DateTime Function() _now;
  StreamSubscription<String?>? _sub;

  Phase phase = Phase.signedOut;
  Repository? repo;
  String? error;
  String? status;
  DateTime? lastSync;
  bool busy = false;

  Future<void> start() async {
    _sub = backend.userChanges.listen((_) => _onUser());
    await _onUser();
  }

  Future<void> _onUser() async {
    final uid = backend.userId;
    if (uid == null) {
      repo = null;
      phase = Phase.signedOut;
      notifyListeners();
      return;
    }
    if (repo != null) return;
    phase = Phase.loading;
    notifyListeners();
    final engine = SyncEngine(
      remote: backend.remote,
      store: await backend.localStoreFor(uid),
      deviceId: await backend.deviceId(),
    );
    await engine.open();
    repo = Repository(engine);
    phase = Phase.ready;
    notifyListeners();
    await syncNow();
    await checkForUpdate();
  }

  Future<void> checkForUpdate() async {
    final u = updater;
    if (u == null) return;
    update = await u.check();
    notifyListeners();
  }

  /// Laddar ner i appen och öppnar Androids installationsdialog.
  Future<void> installUpdate() async {
    final u = updater, info = update;
    if (u == null || info == null) return;
    await for (final s in u.install(info)) {
      updateStatus = s;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    error = null;
    busy = true;
    notifyListeners();
    try {
      await backend.signIn(email.trim(), password);
    } catch (e) {
      error = 'Sign in failed: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await backend.signOut();
    repo = null;
    phase = Phase.signedOut;
    notifyListeners();
  }

  Future<void> syncNow() async {
    final r = repo;
    if (r == null || busy) return;
    busy = true;
    status = 'Syncing…';
    notifyListeners();
    final reports = await r.engine.syncAll();
    final bad = reports.values.where((x) => x.outcome != SyncOutcome.ok).length;
    status = bad == 0 ? 'Synced' : 'Offline — changes are saved on this device';
    if (bad == 0) lastSync = _now();
    busy = false;
    notifyListeners();
  }

  /// Engångsimport från hemsidan (MK1). Kan köras om under testfasen.
  Future<void> importFromWebsite() async {
    final r = repo;
    if (r == null || busy) return;
    busy = true;
    error = null;
    status = 'Importing from the website…';
    notifyListeners();
    try {
      final raw = await backend.fetchMk1State();
      if (raw == null) {
        error = 'No website data found for this account';
      } else {
        final snap = decodeMk1(raw);
        await r.importMk1(snap, _now());
        status = snap.warnings.isEmpty
            ? 'Imported ${snap.history.length} entries'
            : 'Imported ${snap.history.length} entries · ${snap.warnings.length} warnings';
      }
    } catch (e) {
      error = 'Import failed: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
    await syncNow();
  }

  // ── pass ──
  final _rnd = Random.secure();
  int _seq = 0;

  /// Unika id:n: tid + räknare + slump (krockar inte mellan enheter).
  String newId() =>
      '${_now().millisecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}${_rnd.nextInt(1 << 30).toRadixString(36)}';

  /// Startar ett pass, eller återupptar det pågående för samma pass.
  WorkoutController openWorkout(SessionId sessionId) {
    final r = repo!;
    final session = r.program().sessionById(sessionId)!;
    var w = r.activeWorkoutFor(sessionId);
    if (w == null) {
      w = startWorkout(
        session,
        (id) => r.exercise(id) ?? Exercise(id: id, name: id.value, group: MuscleGroup.other, measure: Measure.weight),
        r.history(),
        _now(),
        newId,
      );
      r.saveActiveWorkout(w, _now());
    }
    return WorkoutController(
      repo: r,
      workout: w,
      newId: newId,
      clock: _now,
      onFinished: () async {
        notifyListeners();
        await syncNow();
      },
    );
  }

  /// Undo av ett avslutat pass: blir pågående igen med allt loggat kvar. Kedjan
  /// räknar det som ogjort tills det avslutas på nytt. Samma id → ingen dubblett.
  Future<void> undoWorkout(WorkoutEntry entry) async {
    final w = entry.workout;
    await repo!.saveActiveWorkout(
      Workout(id: w.id, sessionId: w.sessionId, startedAt: w.startedAt, exercises: w.exercises),
      _now(),
    );
    notifyListeners();
    await syncNow();
  }

  /// Undo av en avklarad vilodag.
  Future<void> undoRest(RestEntry entry) async {
    await repo!.deleteHistory(entry, _now());
    notifyListeners();
    await syncNow();
  }

  Future<void> markRestDone(SessionId sessionId, {String? note}) async {
    final r = repo!;
    final session = r.program().sessionById(sessionId)!;
    await r.saveHistory(completeRest(session, _now(), note: note), _now());
    notifyListeners();
    await syncNow();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
