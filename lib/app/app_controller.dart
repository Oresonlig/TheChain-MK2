/// Appens tillstånd: inloggning, synk och import. UI:t lyssnar på den här.
/// Allt mot Supabase går via [Backend] så att UI och logik kan testas utan nät.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repository.dart';
import '../data/sync_engine.dart';
import '../mk1/mk1_codec.dart';

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
  AppController(this.backend, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final Backend backend;
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
