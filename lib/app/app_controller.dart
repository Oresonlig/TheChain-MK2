/// Appens tillstånd: inloggning, synk och import. UI:t lyssnar på den här.
/// Allt mot Supabase går via [Backend] så att UI och logik kan testas utan nät.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/backup.dart';
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

  /// Killswitch-markeringen (mk2_migration): när kontot flyttades till appen,
  /// eller null. Kastar vid nätfel — "vet inte" är inte samma sak som "nej".
  Future<DateTime?> movedToAppAt();

  /// Sätter markeringen. Hemsidan visar sedan "moved to the app" och slutar skriva.
  Future<void> markMovedToApp(String sourceVersion);
}

enum Phase { signedOut, loading, ready }

class AppController extends ChangeNotifier {
  AppController(this.backend, {DateTime Function()? clock, this.updater, this.syncDelay = const Duration(seconds: 3)})
      : _now = clock ?? DateTime.now;

  final Backend backend;

  /// Väntetid efter senaste ändringen i ett pass innan synk — en serie snabba
  /// tryck blir ett anrop, inte tio.
  final Duration syncDelay;
  Timer? _syncTimer;
  bool _syncAgain = false;

  /// Passvyn som är öppen just nu (läses om när synken hämtat något nytt).
  WorkoutController? _openWorkout;

  /// Självuppdatering (null i tester och lokala byggen).
  final Updater? updater;
  UpdateInfo? update;
  String? updateStatus;
  final DateTime Function() _now;
  StreamSubscription<String?>? _sub;

  Phase phase = Phase.signedOut;
  Repository? repo;

  /// Killswitch: kontot är flyttat till appen. null = okänt (inte kollat eller
  /// nätfel) — import kräver ett säkert "nej", annars kan den skriva över appens
  /// data med hemsidans gamla.
  bool? moved;
  DateTime? movedAt;
  String? error;
  String? status;
  DateTime? lastSync;
  bool busy = false;

  Future<void> start() async {
    _sub = backend.userChanges.listen((_) => _onUser());
    await _onUser();
  }

  /// Användaren vars data öppnas just nu. Vid start kommer både start()-anropet
  /// och Supabase "initialSession" — utan spärren öppnades två synkmotorer mot
  /// samma filer (2026-10-04).
  String? _openingUid;

  Future<void> _onUser() async {
    final uid = backend.userId;
    if (uid == null) {
      if (repo != null || phase != Phase.signedOut) _clearSession();
      return;
    }
    if (repo != null || _openingUid == uid) return;
    _openingUid = uid;
    phase = Phase.loading;
    notifyListeners();
    try {
      final engine = SyncEngine(
        remote: backend.remote,
        store: await backend.localStoreFor(uid),
        deviceId: await backend.deviceId(),
      );
      await engine.open();
      // Utloggad (eller bytt konto) medan filerna lästes: öppna inte.
      if (backend.userId != uid) return;
      repo = Repository(engine);
      phase = Phase.ready;
    } catch (e) {
      // Aldrig en evig snurra: tillbaka till inloggningen med beskedet.
      error = 'Could not open the data on this phone: $e';
      phase = Phase.signedOut;
    } finally {
      _openingUid = null;
      notifyListeners();
    }
    if (repo == null) return;
    await syncNow(); // tar även första versionskollen
    await checkMoved();
  }

  /// Nollställer allt som hör till det inloggade kontot.
  void _clearSession() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _syncAgain = false;
    _openWorkout = null;
    moved = null;
    movedAt = null;
    repo = null;
    status = null;
    lastSync = null;
    error = null;
    phase = Phase.signedOut;
    notifyListeners();
  }

  Future<void> checkMoved() async {
    try {
      movedAt = await backend.movedToAppAt();
      moved = movedAt != null;
    } catch (_) {
      // Nätfel: behåll senast kända värde (null om aldrig kollat).
    }
    notifyListeners();
  }

  /// Flyttar kontot till appen: hemsidan slutar fungera för det och import
  /// stängs av. Ångra = radera raden i mk2_migration (Supabase).
  Future<bool> moveToApp(String sourceVersion) async {
    error = null;
    try {
      await backend.markMovedToApp(sourceVersion);
    } catch (e) {
      error = 'Could not move the account: $e';
      notifyListeners();
      return false;
    }
    await checkMoved();
    return moved == true;
  }

  /// Hela appens data som en JSON-sträng (Settings → Export backup).
  String exportBackup(String appVersion) =>
      encodeBackup(buildBackup(repo!.engine, email: backend.userEmail, now: _now(), appVersion: appVersion));

  /// Versionskollen åker med synken (Niklas 2026-10-03: bannern ska dyka upp
  /// utan omstart). Start, återkomst och SYNC NOW kollar alltid; de automatiska
  /// synkarna under ett pass (efter nästan varje set) högst var [updateInterval].
  static const updateInterval = Duration(minutes: 10);
  DateTime? _lastUpdateCheck;

  Future<void> checkForUpdate({bool force = true}) async {
    final u = updater;
    if (u == null) return;
    final now = _now(), last = _lastUpdateCheck;
    if (!force && last != null && now.difference(last) < updateInterval) return;
    _lastUpdateCheck = now;
    // null = ingen nyare ELLER nätfel: en redan hittad version försvinner inte
    // ur bannern för att en koll misslyckas.
    final found = await u.check();
    if (_disposed) return;
    update = found ?? update;
    notifyListeners();
  }

  /// Central versionskoll medan appen syns (Niklas 2026-10-04: på alla vyer,
  /// inte bara när något synkas). Ett litet GET, aldrig i bakgrunden. DEV:
  /// var 3:e minut (bygget tar ~4). Stabila kanalen får ett längre intervall.
  static const updatePollInterval = Duration(minutes: 3);
  Timer? _updatePoll;

  void startUpdatePolling() {
    if (updater == null || _updatePoll != null) return;
    _updatePoll = Timer.periodic(updatePollInterval, (_) => checkForUpdate());
  }

  void stopUpdatePolling() {
    _updatePoll?.cancel();
    _updatePoll = null;
  }

  bool _disposed = false;

  /// Laddar ner i appen och öppnar Androids installationsdialog.
  Future<void> installUpdate() async {
    final u = updater, info = update;
    if (u == null || info == null) return;
    try {
      await for (final s in u.install(info)) {
        updateStatus = s;
        notifyListeners();
      }
    } catch (e) {
      // Annars stod bannern kvar på "Downloading…" och UPDATE var låst för gott.
      updateStatus = 'Update failed: $e';
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
    try {
      await backend.signOut();
    } catch (e) {
      // Servern nåddes inte: logga ut lokalt ändå — aldrig fast i ett halvläge.
      debugPrint('signOut: $e');
    }
    _clearSession();
  }

  /// [auto] = utlöst av en ändring under passet (inte av användaren).
  Future<void> syncNow({bool auto = false}) async {
    final r = repo;
    if (r == null) return;
    if (busy) {
      _syncAgain = true; // en ändring kom under pågående synk — kör igen efteråt
      return;
    }
    _syncTimer?.cancel();
    _syncTimer = null;
    busy = true;
    status = 'Syncing…';
    notifyListeners();
    final reports = await r.engine.syncAll();
    if (!identical(repo, r)) {
      // Utloggad under synken — inget av resultatet hör till nästa inloggning.
      // Hann någon logga in under tiden väntar dess första synk här.
      busy = false;
      notifyListeners();
      if (_syncAgain && repo != null) {
        _syncAgain = false;
        await syncNow();
      }
      return;
    }
    final bad = reports.values.where((x) => x.outcome != SyncOutcome.ok).length;
    status = bad == 0 ? 'Synced' : 'Offline — changes are saved on this device';
    if (bad == 0) lastSync = _now();
    busy = false;
    if (reports.values.any((x) => x.localChanged)) _openWorkout?.reloadFromRepo();
    notifyListeners();
    // Efter synken och utan att vänta in den — kan aldrig fälla synken.
    unawaited(checkForUpdate(force: !auto));
    if (_syncAgain && repo != null) {
      _syncAgain = false;
      await syncNow(auto: true);
    }
  }

  /// Synk strax efter senaste ändringen (pågående pass når molnet medan man
  /// tränar, inte först vid FINISH — beslut 2026-10-02).
  void scheduleSync() {
    if (repo == null) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(syncDelay, () => syncNow(auto: true));
  }

  /// Appen kommer tillbaka från bakgrunden: hämta det andra enheter ändrat.
  Future<void> onResume() => syncNow();

  /// Engångsimport från hemsidan (MK1). Kan köras om under testfasen.
  Future<void> importFromWebsite() async {
    final r = repo;
    if (r == null || busy) return;
    if (moved != false) {
      // Efter flytten skulle en import ersätta appens data med hemsidans gamla.
      error = moved == true
          ? 'Import is off — this account has moved to the app'
          : 'Could not check the account. Connect to the internet and try again';
      notifyListeners();
      return;
    }
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
      // Ett pass i taget (UI:t varnar först; det här är skyddsnätet).
      if (r.activeWorkouts().isNotEmpty) throw const WorkoutError('Another session is in progress — finish or discard it first');
      w = startWorkout(
        session,
        (id) => r.exercise(id) ?? Exercise(id: id, name: id.value, group: MuscleGroup.other, measure: Measure.weight),
        r.history(),
        _now(),
        newId,
      );
      r.saveActiveWorkout(w, _now());
      scheduleSync(); // andra enheter ska se att passet pågår
    }
    late final WorkoutController wc;
    wc = WorkoutController(
      repo: r,
      workout: w,
      newId: newId,
      clock: _now,
      onChanged: scheduleSync,
      onFinished: () async {
        if (identical(_openWorkout, wc)) _openWorkout = null;
        notifyListeners();
        await syncNow();
      },
    );
    return _openWorkout = wc;
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

  // ── vikt och inställningar ──
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Dagens vägning (en per dag — samma dag skrivs över, senaste vinner i synken).
  Future<void> logBodyweight(double kg) async {
    await repo!.saveBodyweight(BodyweightEntry(date: dayKey(_now()), kg: kg), _now());
    notifyListeners();
    await syncNow();
  }

  /// UNDO efter radering: samma dag och vikt tillbaka (nyare stämpel vinner).
  Future<void> restoreBodyweight(BodyweightEntry e) async {
    await repo!.saveBodyweight(e, _now());
    notifyListeners();
    await syncNow();
  }

  Future<void> deleteBodyweight(String date) async {
    await repo!.deleteBodyweight(date, _now());
    notifyListeners();
    await syncNow();
  }

  Future<void> updateSettings(UserSettings s) async {
    await repo!.saveSettings(s, _now());
    notifyListeners();
    await syncNow();
  }

  /// Undo av en avklarad vilodag.
  Future<void> undoRest(RestEntry entry) async {
    await repo!.deleteHistory(entry, _now());
    notifyListeners();
    await syncNow();
  }

  /// Hoppar över ett pass med obligatorisk anledning. Ett påbörjat pass måste
  /// kasseras först — aldrig två utvägar samtidigt.
  Future<void> skipSession(SessionId sessionId, String reason) async {
    final r = repo!;
    if (r.activeWorkoutFor(sessionId) != null) throw const WorkoutError('Discard the started session first');
    final session = r.program().sessionById(sessionId)!;
    await r.saveHistory(skippedEntry(session, _now(), reason), _now());
    notifyListeners();
    await syncNow();
  }

  Future<void> undoSkip(SkippedEntry entry) async {
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
    _disposed = true;
    stopUpdatePolling();
    _syncTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
