/// Backend mot riktiga Supabase. Testas på telefonen när schemat körts.
library;

import 'dart:io';
import 'dart:math';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/file_store.dart';
import '../data/supabase_config.dart';
import '../data/supabase_remote.dart';
import '../data/sync_engine.dart';
import 'app_controller.dart';

class SupabaseBackend implements Backend {
  SupabaseBackend._(this._client) : remote = SupabaseRemote(_client);

  static Future<SupabaseBackend> init() async {
    // Projektets publika nyckel (den äldre anon-JWT:n fungerar som publishable key).
    await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabaseAnonKey);
    return SupabaseBackend._(Supabase.instance.client);
  }

  final SupabaseClient _client;

  @override
  final Remote remote;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  String? get userEmail => _client.auth.currentUser?.email;

  @override
  Stream<String?> get userChanges => _client.auth.onAuthStateChange.map((s) => s.session?.user.id);

  @override
  Future<void> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut(); // annars väljs samma konto tyst nästa gång
    } catch (_) {}
    await _client.auth.signOut();
  }

  /// Webbklientens id (Google Cloud → "MK1"): Supabase kontrollerar id-tokenets
  /// mottagare mot den. Android-klienterna (paketnamn + SHA-1) behövs bara hos
  /// Google, inte i koden.
  static const _googleServerClientId = '776616187427-hn8io3ie5j5oriq4iipiieruasggatgb.apps.googleusercontent.com';
  bool _googleReady = false;

  @override
  Future<bool> signInWithGoogle() async {
    final g = GoogleSignIn.instance;
    if (!_googleReady) {
      await g.initialize(serverClientId: _googleServerClientId);
      _googleReady = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await g.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw Exception(e.description ?? e.code.name);
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw Exception('Google gave no ID token.');
    await _auth(() => _client.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken));
    return true;
  }

  /// Länken i mejlet går till hemsidans återställning (som i MK1); koden i
  /// samma mejl används i appen. Mallen i Supabase bär båda.
  @override
  Future<void> sendPasswordReset(String email) =>
      _auth(() => _client.auth.resetPasswordForEmail(email, redirectTo: 'https://thechain.training'));

  @override
  Future<void> verifyRecoveryCode(String email, String code) =>
      _auth(() => _client.auth.verifyOTP(email: email, token: code, type: OtpType.recovery));

  @override
  Future<void> updatePassword(String password) =>
      _auth(() => _client.auth.updateUser(UserAttributes(password: password)));

  /// Supabase-meddelandet ("Token has expired or is invalid") i stället för
  /// AuthException-dumpen.
  static Future<void> _auth(Future<Object?> Function() call) async {
    try {
      await call();
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  @override
  Future<LocalStore> localStoreFor(String userId) async {
    final docs = await getApplicationDocumentsDirectory();
    return FileLocalStore(Directory('${docs.path}${Platform.pathSeparator}sync${Platform.pathSeparator}$userId'));
  }

  /// Slumpat, beständigt enhets-id (del av synkstämpeln).
  @override
  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
      await prefs.setString('device_id', id);
    }
    return id;
  }

  @override
  Future<Map<String, Object?>?> fetchMk1State() async {
    final uid = userId;
    if (uid == null) return null;
    final row = await _client.from('app_state').select('data').eq('id', uid).maybeSingle();
    final data = row?['data'];
    return data is Map ? data.cast<String, Object?>() : null;
  }

  @override
  Future<DateTime?> movedToAppAt() async {
    final uid = userId;
    if (uid == null) return null;
    final row = await _client.from('mk2_migration').select('migrated_at').eq('user_id', uid).maybeSingle();
    final at = row?['migrated_at'];
    return at is String ? DateTime.parse(at) : null;
  }

  @override
  Future<void> markMovedToApp(String sourceVersion) =>
      _client.from('mk2_migration').insert({'source_app_version': sourceVersion});
}
