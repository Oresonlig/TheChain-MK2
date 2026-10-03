// Synk under pågående pass (beslut 2026-10-02): ändringar når molnet strax
// efter att de gjorts, och en annan enhets ändringar syns i öppen passvy.
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/app/workout_controller.dart';
import 'package:the_chain/data/json_codec.dart';
import 'package:the_chain/data/sync_engine.dart';
import 'package:the_chain/domain/domain.dart';

import '../data/fake_remote.dart';
import 'fake_backend.dart';

const _delay = Duration(milliseconds: 5);

Map<String, Object?> mk1() => {
      'sessionOrder': ['A'],
      'restSlots': <int>[],
    };

Future<AppController> phone(FakeRemote server, String device, {bool import = false}) async {
  final app = AppController(FakeBackend(mk1: mk1(), server: server, device: device), syncDelay: _delay);
  await app.start();
  await app.signIn('x', 'secret');
  await pumpEventQueue();
  if (import) await app.importFromWebsite();
  return app;
}

Future<void> settle() async {
  await Future<void>.delayed(_delay * 4);
  await pumpEventQueue();
}

SessionId sessionOf(AppController a) => a.repo!.program().sessions.first.id;

/// Loggar första arbetssetet i första övningen.
void logFirst(WorkoutController wc) {
  final row = wc.workout.exercises.first;
  final s = row.sets.firstWhere((x) => x.kind == SetKind.work);
  wc.setValues(row.id, s.id, const SetValues(weight: 100, reps: 5));
  wc.toggleLog(row.id, s.id);
}

bool serverHasLoggedSet(FakeRemote server) => server.table(Tables.workouts).values.any((r) {
      if (r.deleted) return false;
      final h = historyFromJson(r.data!);
      return h is WorkoutEntry && h.workout.exercises.any((e) => e.sets.any((s) => s.isLogged));
    });

void main() {
  test('loggat set når servern strax efteråt — inte först vid FINISH', () async {
    final server = FakeRemote();
    final a = await phone(server, 'phone', import: true);
    final wc = a.openWorkout(sessionOf(a));
    logFirst(wc);
    expect(serverHasLoggedSet(server), isFalse, reason: 'väntar på fördröjningen');
    await settle();
    expect(serverHasLoggedSet(server), isTrue);
    a.dispose();
  });

  test('snabba tryck blir en synk, inte en per tryck', () async {
    final server = FakeRemote();
    final a = await phone(server, 'phone', import: true);
    final wc = a.openWorkout(sessionOf(a));
    await settle(); // startens sparning
    final before = server.pushCalls;
    final row = wc.workout.exercises.first;
    for (var i = 0; i < 5; i++) {
      wc.addSet(row.id, SetKind.work);
    }
    await settle();
    expect(server.pushCalls - before, 1);
    a.dispose();
  });

  test('annan enhets ändring syns i öppen passvy efter synk', () async {
    final server = FakeRemote();
    final a = await phone(server, 'phone', import: true);
    final wcA = a.openWorkout(sessionOf(a));
    await settle();
    final b = await phone(server, 'tablet');
    final wcB = b.openWorkout(sessionOf(b));
    expect(wcB.workout.id, wcA.workout.id, reason: 'samma pågående pass');
    logFirst(wcB);
    await settle();
    await a.onResume();
    expect(wcA.workout.exercises.first.sets.any((s) => s.isLogged), isTrue);
    a.dispose();
    b.dispose();
  });

  test('avslutat på annan enhet: öppen vy spärras och väcker inte passet igen', () async {
    final server = FakeRemote();
    final a = await phone(server, 'phone', import: true);
    final wcA = a.openWorkout(sessionOf(a));
    await settle();
    final b = await phone(server, 'tablet');
    await b.openWorkout(sessionOf(b)).discard();
    await settle();
    await a.onResume();
    expect(wcA.closedElsewhere, isTrue);
    expect(wcA.takeError(), contains('another device'));
    logFirst(wcA);
    await settle();
    expect(a.repo!.activeWorkouts(), isEmpty);
    expect(server.table(Tables.workouts).values.where((r) => !r.deleted), isEmpty);
    a.dispose();
    b.dispose();
  });
}
