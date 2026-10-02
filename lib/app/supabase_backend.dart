/// Backend mot riktiga Supabase. Testas på telefonen när schemat körts.
library;

import 'dart:io';
import 'dart:math';

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
  Future<void> signOut() => _client.auth.signOut();

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
}
