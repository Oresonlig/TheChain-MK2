import 'dart:async';

import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/data/sync_engine.dart';

import '../data/fake_remote.dart';

class FakeBackend implements Backend {
  FakeBackend({this.mk1, FakeRemote? server, this.device = 'phone'}) : server = server ?? FakeRemote();

  final Map<String, Object?>? mk1;
  final FakeRemote server;

  /// Enhets-id — två FakeBackend med samma server = två telefoner.
  final String device;
  final _users = StreamController<String?>.broadcast();
  final _stores = <String, InMemoryLocalStore>{};
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

  @override
  Future<LocalStore> localStoreFor(String userId) async => _stores.putIfAbsent(userId, InMemoryLocalStore.new);
  @override
  Future<String> deviceId() async => device;
  @override
  Future<Map<String, Object?>?> fetchMk1State() async => mk1;
}
