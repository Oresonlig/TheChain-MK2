import 'dart:async';
import 'dart:io';

import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/data/sync_engine.dart';

import '../data/fake_remote.dart';

class _FlakyStore extends InMemoryLocalStore {
  _FlakyStore(this.backend);
  final FakeBackend backend;
  @override
  Future<void> save(String table, TableState state) {
    if (backend.diskFull) throw const FileSystemException('No space left on device');
    return super.save(table, state);
  }
}

class FakeBackend implements Backend {
  FakeBackend({this.mk1, FakeRemote? server, this.device = 'phone'}) : server = server ?? FakeRemote();

  final Map<String, Object?>? mk1;
  final FakeRemote server;

  /// Enhets-id — två FakeBackend med samma server = två telefoner.
  final String device;
  final _users = StreamController<String?>.broadcast();
  final _stores = <String, InMemoryLocalStore>{};

  /// Telefonens lagring kastar vid varje sparning (fullt minne).
  bool diskFull = false;
  String? _uid;
  String password = 'secret';

  @override
  String? get userId => _uid;
  @override
  String? get userEmail => _uid == null ? null : 'niklas@example.com';
  @override
  Stream<String?> get userChanges => _users.stream;
  @override
  Remote get remote => server;

  @override
  Future<void> signIn(String email, String pw) async {
    if (pw != password) throw Exception('Invalid login credentials');
    _uid = 'user-1';
    _users.add(_uid);
  }

  @override
  Future<void> signOut() async {
    _uid = null;
    _users.add(null);
  }

  /// Google: 'ok' loggar in, 'cancel' = användaren stängde väljaren, annars fel.
  String google = 'ok';

  @override
  Future<bool> signInWithGoogle() async {
    if (google == 'cancel') return false;
    if (google != 'ok') throw Exception(google);
    _uid = 'user-1';
    _users.add(_uid);
    return true;
  }

  /// Nytt konto: kod i mejlet (som Supabase med "Confirm email" på).
  String? signupCode;

  @override
  Future<bool> signUp(String email, String password, String name) async {
    this.password = password;
    signupCode = '654321';
    return false;
  }

  @override
  Future<void> verifySignupCode(String email, String code) async {
    if (code != signupCode) throw Exception('Token has expired or is invalid');
    _uid = 'user-1';
    _users.add(_uid);
  }

  @override
  Future<void> resendSignupCode(String email) async => signupCode = '654321';

  /// Glömt lösenord: senaste skickade koden (null = inget mejl).
  String? sentCode;
  bool failPasswordUpdate = false;

  @override
  Future<void> sendPasswordReset(String email) async => sentCode = '123456';

  @override
  Future<void> verifyRecoveryCode(String email, String code) async {
    if (sentCode == null || code != sentCode) throw Exception('Token has expired or is invalid');
    sentCode = null; // förbrukad
    _uid = 'user-1';
    _users.add(_uid);
  }

  @override
  Future<void> updatePassword(String pw) async {
    if (failPasswordUpdate) throw Exception('New password should be different from the old password.');
    password = pw;
  }

  /// Som Supabase vid appstart: sparad inloggning + "initialSession"-händelse.
  void restoreSession() => _uid = 'user-1';
  void emitAuthEvent() => _users.add(_uid);

  /// Hur många gånger lokala data öppnats (ska vara en per inloggning).
  int storeOpens = 0;

  @override
  Future<LocalStore> localStoreFor(String userId) async {
    storeOpens++;
    return _stores.putIfAbsent(userId, () => _FlakyStore(this));
  }
  @override
  Future<String> deviceId() async => device;
  @override
  Future<Map<String, Object?>?> fetchMk1State() async => mk1;

  /// mk2_migration på "servern" (delas inte mellan FakeBackend-instanser).
  DateTime? movedAt;
  bool migrationOffline = false;

  @override
  Future<DateTime?> movedToAppAt() async {
    if (migrationOffline) throw Exception('offline');
    return movedAt;
  }

  @override
  Future<void> markMovedToApp(String sourceVersion) async {
    if (migrationOffline) throw Exception('offline');
    movedAt ??= DateTime(2026, 10, 3, 15);
  }
}
