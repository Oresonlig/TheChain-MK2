import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';

const bench = ExerciseId('bench_press_bb'), deadlift = ExerciseId('deadlift'), row = ExerciseId('row');
const chins = ExerciseId('chins'), hang = ExerciseId('dead_hang'), flyes = ExerciseId('flyes');

final lib = <ExerciseId, Exercise>{
  bench: const Exercise(id: bench, name: 'Bench Press (BB)', group: MuscleGroup.chest, measure: Measure.weight),
  deadlift: const Exercise(id: deadlift, name: 'Deadlift', group: MuscleGroup.back, measure: Measure.weight, scheme: SetScheme.ramp),
  row: const Exercise(id: row, name: 'Unilateral Row', group: MuscleGroup.back, measure: Measure.weight, unilateral: true),
  chins: const Exercise(id: chins, name: 'Chins', group: MuscleGroup.back, measure: Measure.bodyweight),
  hang: const Exercise(id: hang, name: 'Dead Hang', group: MuscleGroup.back, measure: Measure.bodyweightTimed),
  flyes: const Exercise(id: flyes, name: 'Flyes (Cable)', group: MuscleGroup.chest, measure: Measure.weight),
};
Exercise cat(ExerciseId id) => lib[id]!;

var _n = 0;
String gen() => 'id${_n++}';

const sessionB = Session(id: SessionId('B'), name: 'Back', slots: [
  Slot(id: SlotId('B1'), exerciseId: hang),
  Slot(id: SlotId('B2'), exerciseId: deadlift),
  Slot(id: SlotId('B3'), exerciseId: row),
]);
final now = DateTime(2026, 10, 2, 18);

int warm(WorkoutExercise r) => r.sets.where((s) => s.kind == SetKind.warmup).length;
int work(WorkoutExercise r) => r.sets.where((s) => s.kind == SetKind.work).length;

void main() {
  group('standardset (MK1:s regler)', () {
    test('utan historik: HIT 2+1, ramp 0+4, unilateral 2+1, kroppsvikt 0+3, tid 0+1', () {
      expect(defaultCounts(cat(bench), const []), const SetCounts(2, 1));
      expect(defaultCounts(cat(deadlift), const []), const SetCounts(0, 4));
      expect(defaultCounts(cat(row), const []), const SetCounts(2, 1));
      expect(defaultCounts(cat(chins), const []), const SetCounts(0, 3));
      expect(defaultCounts(cat(hang), const []), const SetCounts(0, 1));
    });

    test('förra passets antal följer med, max 8', () {
      SetEntry s(SetKind k) => SetEntry(id: SetId(gen()), kind: k, values: const SetValues(weight: 60, reps: 5), isLogged: true);
      final hist = [
        WorkoutEntry(
          workout: Workout(id: const WorkoutId('old'), sessionId: const SessionId('A'), startedAt: DateTime(2026, 9, 1), finishedAt: DateTime(2026, 9, 1),
              exercises: [WorkoutExercise(id: 'x', exerciseId: bench, measure: Measure.weight, status: ExerciseStatus.done,
                  sets: [s(SetKind.warmup), ...List.generate(10, (_) => s(SetKind.work))])]),
        ),
      ];
      expect(defaultCounts(cat(bench), hist), const SetCounts(1, 8));
    });
  });

  group('startWorkout', () {
    test('en rad per plats med standardset; programmet orört', () {
      final w = startWorkout(sessionB, cat, const [], now, gen);
      expect(w.exercises.map((r) => r.exerciseId), [hang, deadlift, row]);
      expect(w.exercises.map((r) => r.slotId), const [SlotId('B1'), SlotId('B2'), SlotId('B3')]);
      expect(warm(w.exercises[1]), 0); // ramp
      expect(work(w.exercises[1]), 4);
      expect(w.isFinished, isFalse);
      expect(w.canFinish, isFalse);
    });

    test('vilodag kan inte startas som pass', () {
      const rest = Session(id: SessionId('V'), name: 'Rest', kind: SessionKind.rest);
      expect(() => startWorkout(rest, cat, const [], now, gen), throwsA(isA<WorkoutError>()));
    });
  });

  group('set', () {
    late Workout w;
    late WorkoutExercise r;
    setUp(() {
      w = startWorkout(sessionB, cat, const [], now, gen);
      r = w.exercises[2]; // row: 2 uppvärmning + 1 arbete
    });

    test('skriva, sätta mål och logga', () {
      final sid = r.sets.last.id;
      w = setValues(w, r.id, sid, const SetValues(weight: 40, reps: 9));
      w = setTarget(w, r.id, sid, const SetValues(reps: 10));
      w = logSet(w, r.id, sid);
      final s = w.exercises[2].sets.last;
      expect(s.isLogged, isTrue);
      expect(s.missed(Measure.weight), isTrue);
    });

    test('uppvärmning läggs efter sista uppvärmningen, arbete sist', () {
      w = addSet(w, r.id, SetKind.warmup, gen);
      w = addSet(w, r.id, SetKind.work, gen);
      expect(w.exercises[2].sets.map((s) => s.kind),
          [SetKind.warmup, SetKind.warmup, SetKind.warmup, SetKind.work, SetKind.work]);
    });

    test('loggat set tas inte bort tyst', () {
      final sid = r.sets.last.id;
      w = logSet(setValues(w, r.id, sid, const SetValues(weight: 40, reps: 10)), r.id, sid);
      expect(() => removeSet(w, r.id, sid), throwsA(isA<WorkoutError>()));
      w = removeSet(unlogSet(w, r.id, sid), r.id, sid);
      expect(w.exercises[2].sets.length, 2);
    });

    test('ingenting ändras i bakgrunden: ett borttaget set kommer inte tillbaka', () {
      w = removeSet(w, r.id, r.sets.first.id);
      w = setValues(w, r.id, r.sets.last.id, const SetValues(weight: 40, reps: 10));
      w = logSet(w, r.id, r.sets.last.id);
      expect(w.exercises[2].sets.length, 2);
    });
  });

  group('byten och extra', () {
    test('tillfälligt byte: nya set, original sparat, byte tillbaka nollställer', () {
      var w = startWorkout(sessionB, cat, const [], now, gen);
      final r = w.exercises[0];
      w = swapTemporarily(w, r.id, cat(chins), const [], gen);
      expect(w.exercises[0].exerciseId, chins);
      expect(w.exercises[0].temporarySwapFrom, hang);
      expect(w.exercises[0].measure, Measure.bodyweight);
      expect(work(w.exercises[0]), 3);
      w = swapTemporarily(w, r.id, cat(hang), const [], gen);
      expect(w.exercises[0].temporarySwapFrom, isNull);
    });

    test('byte blockeras när rader har loggade set (inget loggat försvinner)', () {
      var w = startWorkout(sessionB, cat, const [], now, gen);
      final r = w.exercises[0];
      w = logSet(setValues(w, r.id, r.sets.first.id, const SetValues(secs: 60)), r.id, r.sets.first.id);
      expect(() => swapTemporarily(w, r.id, cat(chins), const [], gen), throwsA(isA<WorkoutError>()));
    });

    test('extraövning läggs sist utan plats och kan tas bort', () {
      var w = startWorkout(sessionB, cat, const [], now, gen);
      w = addExtra(w, cat(flyes), const [], gen);
      expect(w.exercises.last.isExtra, isTrue);
      expect(() => removeExtra(w, w.exercises.first.id), throwsA(isA<WorkoutError>()));
      w = removeExtra(w, w.exercises.last.id);
      expect(w.exercises.length, 3);
    });
  });

  group('avsluta', () {
    test('kräver att alla rader är gjorda eller överhoppade; tomma set följer inte med', () {
      var w = startWorkout(sessionB, cat, const [], now, gen);
      expect(() => finishWorkout(w, now, const []), throwsA(isA<WorkoutError>()));
      final r0 = w.exercises[0];
      w = logSet(setValues(w, r0.id, r0.sets.first.id, const SetValues(secs: 75)), r0.id, r0.sets.first.id);
      w = setStatus(w, r0.id, ExerciseStatus.done);
      w = setStatus(w, w.exercises[1].id, ExerciseStatus.skipped);
      w = setStatus(w, w.exercises[2].id, ExerciseStatus.done);
      final res = finishWorkout(w, now.add(const Duration(hours: 1)), const []);
      final done = res.entry.workout;
      expect(done.isFinished, isTrue);
      expect(done.exercises[0].sets.length, 1);
      expect(done.exercises[2].sets, isEmpty);
      expect(() => setStatus(done, done.exercises[0].id, ExerciseStatus.open), throwsA(isA<WorkoutError>()));
    });

    test('vilodag med och utan anteckning', () {
      const rest = Session(id: SessionId('V'), name: 'Rest', kind: SessionKind.rest);
      expect(completeRest(rest, now, note: '  lätt promenad ').note, 'lätt promenad');
      expect(completeRest(rest, now, note: '   ').note, isNull);
      expect(() => completeRest(sessionB, now), throwsA(isA<WorkoutError>()));
    });
  });

  group('programändringar', () {
    const program = Program(sessions: [sessionB]);
    const b = SessionId('B'), b1 = SlotId('B1');

    test('permanent byte sparar originalet, även efter flera byten, och kan ångras', () {
      var p = swapPermanently(program, b, b1, chins);
      p = swapPermanently(p, b, b1, flyes);
      final slot = p.sessions.first.slots.first;
      expect(slot.exerciseId, flyes);
      expect(slot.originalExerciseId, hang);
      p = revertSwap(p, b, b1);
      expect(p.sessions.first.slots.first.exerciseId, hang);
      expect(p.sessions.first.slots.first.isPermanentlySwapped, isFalse);
    });

    test('lägga till, flytta och ta bort platser och pass', () {
      var p = addSlot(program, b, const Slot(id: SlotId('B4'), exerciseId: flyes));
      p = moveSlot(p, b, const SlotId('B4'), 0);
      expect(p.sessions.first.slots.first.id, const SlotId('B4'));
      p = removeSlot(p, b, const SlotId('B4'));
      expect(p.sessions.first.slots.length, 3);
      p = addSession(p, const Session(id: SessionId('V'), name: 'Rest', kind: SessionKind.rest), at: 0);
      p = moveSession(p, const SessionId('V'), 1);
      expect(p.sessions.map((s) => s.id), const [SessionId('B'), SessionId('V')]);
      expect(() => addSlot(p, const SessionId('V'), const Slot(id: SlotId('x'), exerciseId: bench)),
          throwsA(isA<WorkoutError>()));
      p = renameSession(p, b, '  Back heavy ');
      expect(p.sessionById(b)!.name, 'Back heavy');
    });
  });
}
