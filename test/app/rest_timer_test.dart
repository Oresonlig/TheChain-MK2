import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/app/app_controller.dart';
import 'package:the_chain/app/rest_timer.dart';
import 'package:the_chain/domain/domain.dart';

import 'fake_backend.dart';
import 'workout_controller_test.dart' show mk1;

class RecordingAlarm implements RestAlarm {
  final scheduled = <DateTime>[];
  final wakes = <bool>[];
  int cancels = 0;
  @override
  Future<void> schedule(DateTime end, {bool wakeScreen = true}) async {
    scheduled.add(end);
    wakes.add(wakeScreen);
  }
  @override
  Future<void> cancel() async => cancels++;
  int clears = 0;
  @override
  Future<void> clearDone() async => clears++;
  @override
  Future<bool?> requestWakeScreen() async => true;
}

void main() {
  group('RestTimer', () {
    late DateTime now;
    late RecordingAlarm alarm;
    late RestTimer timer;
    setUp(() {
      now = DateTime(2026, 10, 5, 18);
      alarm = RecordingAlarm();
      timer = RestTimer(alarm: alarm, clock: () => now, tick: const Duration(hours: 1));
    });
    tearDown(() => timer.dispose());

    test('räknar ner mot en absolut sluttid och schemalägger signalen', () {
      timer.start(120);
      expect(timer.running, isTrue);
      expect(timer.remainingSecs, 120);
      expect(alarm.scheduled.single, now.add(const Duration(seconds: 120)));
      now = now.add(const Duration(seconds: 75, milliseconds: 400));
      expect(timer.remainingSecs, 45); // avrundat uppåt
      expect(fmtRest(timer.remainingSecs), '45s');
      expect(fmtRest(105), '1:45');
    });

    test('+30/−30 flyttar signalen; under noll stoppar; ✕ tar bort signalen', () {
      timer.start(60);
      timer.adjust(RestTimer.step);
      expect(timer.remainingSecs, 90);
      expect(alarm.scheduled.last, now.add(const Duration(seconds: 90)));
      timer.adjust(-RestTimer.step);
      timer.adjust(-RestTimer.step);
      expect(timer.remainingSecs, 30);
      timer.adjust(-RestTimer.step);
      expect(timer.running, isFalse);
      expect(alarm.cancels, 1);
      timer.start(60);
      timer.stop();
      expect(timer.running, isFalse);
      expect(alarm.cancels, 2);
    });

    test('nytt arbetsset startar om från början', () {
      timer.start(120);
      now = now.add(const Duration(seconds: 100));
      timer.start(120);
      expect(timer.remainingSecs, 120);
      expect(alarm.scheduled.length, 2);
    });

    test('tillbaka i appen: signalen rensas — men inte mitt i en vila', () {
      timer.appResumed();
      expect(alarm.clears, 1);
      timer.start(60);
      timer.appResumed();
      expect(alarm.clears, 1, reason: 'den schemalagda signalen får inte försvinna');
      now = now.add(const Duration(seconds: 61));
      timer.appResumed();
      expect(alarm.clears, 2);
    });

    test('fri vilotid i Settings: 10 s – 10 min', () {
      expect(clampRestSecs(45), 45);
      expect(clampRestSecs(5), kMinRestSecs);
      expect(clampRestSecs(900), kMaxRestSecs);
      expect(fmtRestChoice(45), '0:45');
      expect(fmtRestChoice(135), '2:15');
    });

    test('noll → "rest over" en stund, sedan borta av sig själv', () {
      timer.start(10);
      now = now.add(const Duration(seconds: 11));
      expect(timer.done, isTrue);
      expect(timer.remainingSecs, lessThanOrEqualTo(0));
    });
  });

  group('i passet', () {
    Future<(AppController, RecordingAlarm)> ready({required bool enabled}) async {
      var t = DateTime(2026, 10, 2, 18);
      final alarm = RecordingAlarm();
      final app = AppController(
        FakeBackend(mk1: mk1()),
        clock: () => t = t.add(const Duration(seconds: 1)),
        restTimer: RestTimer(alarm: alarm, tick: const Duration(hours: 1)),
      );
      await app.start();
      await app.signIn('x', 'secret');
      await pumpEventQueue();
      await app.importFromWebsite();
      await app.updateSettings(UserSettings(restTimerEnabled: enabled, restTimerSecs: 90, restWakeScreen: false));
      return (app, alarm);
    }

    test('startar vid loggat arbetsset, inte vid uppvärmning; stoppas vid avslut', () async {
      final (app, alarm) = await ready(enabled: true);
      final wc = app.openWorkout(const SessionId('A'));
      final row = wc.workout.exercises.firstWhere((r) => r.sets.any((s) => s.kind == SetKind.warmup));
      final warm = row.sets.firstWhere((s) => s.kind == SetKind.warmup);
      wc.setValues(row.id, warm.id, const SetValues(weight: 40, reps: 8));
      wc.toggleLog(row.id, warm.id);
      expect(app.restTimer.running, isFalse);
      final work = row.sets.firstWhere((s) => s.kind == SetKind.work);
      wc.setValues(row.id, work.id, const SetValues(weight: 80, reps: 5));
      wc.toggleLog(row.id, work.id);
      expect(app.restTimer.running, isTrue);
      expect(alarm.scheduled.length, 1);
      expect(alarm.wakes.single, isFalse, reason: 'SCREEN WAKE-UP av i Settings');
      // Låsa upp ett set startar inte om timern.
      wc.toggleLog(row.id, work.id);
      expect(alarm.scheduled.length, 1);
      await wc.discard();
      expect(app.restTimer.running, isFalse);
      app.restTimer.dispose();
    });

    test('avstängd i Settings → ingen timer', () async {
      final (app, alarm) = await ready(enabled: false);
      final wc = app.openWorkout(const SessionId('A'));
      final row = wc.workout.exercises.first;
      final work = row.sets.firstWhere((s) => s.kind == SetKind.work);
      wc.setValues(row.id, work.id, const SetValues(weight: 80, reps: 5));
      wc.toggleLog(row.id, work.id);
      expect(app.restTimer.running, isFalse);
      expect(alarm.scheduled, isEmpty);
    });
  });
}
