// PR-motorn och "förra gången". Reglerna är MK1:s (getAllPRs, getLastSession,
// getExerciseProgression) — samlade i en motor.
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';

const bench = ExerciseId('bench_press_bb');
const chins = ExerciseId('chins');
const sessionA = SessionId('A');
var _n = 0;

SetEntry work(SetValues v, {bool excluded = false, bool logged = true, double? bw, SetValues? target}) => SetEntry(
    id: SetId('s${_n++}'),
    kind: SetKind.work,
    values: v,
    target: target,
    isLogged: logged,
    excludeFromRecords: excluded,
    bodyweightKg: bw);
SetEntry warmup(SetValues v) => SetEntry(id: SetId('s${_n++}'), kind: SetKind.warmup, values: v, isLogged: true);

WorkoutEntry entry(
  DateTime date,
  List<WorkoutExercise> exercises, {
  EntrySource source = EntrySource.app,
}) =>
    WorkoutEntry(
      source: source,
      workout: Workout(
        id: WorkoutId('w${_n++}'),
        sessionId: sessionA,
        startedAt: date,
        finishedAt: date.add(const Duration(hours: 1)),
        exercises: exercises,
      ),
    );

WorkoutExercise ex(ExerciseId id, List<SetEntry> sets,
        {Measure m = Measure.weight, ExerciseStatus status = ExerciseStatus.done}) =>
    WorkoutExercise(id: 'r${_n++}', exerciseId: id, measure: m, sets: sets, status: status);

final d1 = DateTime(2026, 9, 1), d2 = DateTime(2026, 9, 8), d3 = DateTime(2026, 9, 15);

void main() {
  group('personalRecords', () {
    test('bytt mätsätt startar om rekordet; tillbaka ger det gamla igen (2026-10-04)', () {
      final h = [
        entry(d1, [ex(bench, [work(const SetValues(weight: 100, reps: 5))])]),
        entry(d2, [ex(bench, [work(const SetValues(secs: 60))], m: Measure.timed)]),
      ];
      expect(personalRecords(h, measureOf: (_) => Measure.weight)[bench]!.value, 100);
      final timed = personalRecords(h, measureOf: (_) => Measure.timed)[bench]!;
      expect((timed.value, timed.measure), (60, Measure.timed));
      expect(personalRecords(h, measureOf: (_) => Measure.repsOnly)[bench], isNull);
      // En rad per övning, aldrig två.
      expect(personalRecords(h, measureOf: (_) => Measure.weight).length, 1);
      expect(progression(h, bench, measure: Measure.timed).map((p) => p.value), [60]);
      expect(progression(h, bench).length, 2);
    });

    test('högsta vikten över alla pass vinner', () {
      final prs = personalRecords([
        entry(d1, [ex(bench, [work(const SetValues(weight: 100, reps: 5))])]),
        entry(d2, [ex(bench, [work(const SetValues(weight: 110, reps: 3))])]),
      ]);
      expect(prs[bench]!.value, 110);
      expect(prs[bench]!.date, d2);
    });

    test('missat set med utförda reps blir PR', () {
      final prs = personalRecords([
        entry(d1, [ex(bench, [work(const SetValues(weight: 100, reps: 5))])]),
        entry(d2, [ex(bench, [work(const SetValues(weight: 105, reps: 3), target: const SetValues(reps: 4))])]),
      ]);
      expect(prs[bench]!.value, 105);
      expect(prs[bench]!.set.missed(Measure.weight), isTrue);
    });

    test('FAIL utan mål: utförda reps kan bli PR; 0 reps (försöket gick inte) blir aldrig PR', () {
      final prs = personalRecords([
        entry(d1, [ex(bench, [work(const SetValues(weight: 100, reps: 1))])]),
        entry(d2, [ex(bench, [work(const SetValues(weight: 140, reps: 0), target: SetValues.empty)])]),
        entry(d2.add(const Duration(days: 1)), [ex(bench, [work(const SetValues(weight: 100, reps: 3), target: SetValues.empty)])]),
      ]);
      expect(prs[bench]!.value, 100);
      expect(prs[bench]!.set.values.reps, 3); // 3 × 100 slår 1 × 100 trots FAIL
    });

    test('uppvärmning, exkluderade och överhoppade räknas aldrig', () {
      final prs = personalRecords([
        entry(d1, [
          ex(bench, [warmup(const SetValues(weight: 200, reps: 1)), work(const SetValues(weight: 150, reps: 2), excluded: true), work(const SetValues(weight: 100, reps: 5))]),
        ]),
        entry(d2, [ex(bench, [work(const SetValues(weight: 300, reps: 1))], status: ExerciseStatus.skipped)]),
      ]);
      expect(prs[bench]!.value, 100);
    });

    test('ej loggade set räknas aldrig', () {
      final prs = personalRecords([
        entry(d1, [ex(bench, [work(const SetValues(weight: 120, reps: 5), logged: false), work(const SetValues(weight: 100, reps: 5))])]),
      ]);
      expect(prs[bench]!.value, 100);
    });

    test('lika vikt → fler reps vinner', () {
      final prs = personalRecords([
        entry(d1, [ex(bench, [work(const SetValues(weight: 100, reps: 5))])]),
        entry(d2, [ex(bench, [work(const SetValues(weight: 100, reps: 8))])]),
      ]);
      expect(prs[bench]!.set.values.reps, 8);
    });

    test('helt lika → det äldsta behålls', () {
      final prs = personalRecords([
        entry(d2, [ex(bench, [work(const SetValues(weight: 100, reps: 5))])]),
        entry(d1, [ex(bench, [work(const SetValues(weight: 100, reps: 5))])]),
      ]);
      expect(prs[bench]!.date, d1);
    });

    test('dolda övningar utesluts', () {
      final prs = personalRecords([
        entry(d1, [ex(bench, [work(const SetValues(weight: 100, reps: 5))])]),
      ], hidden: {bench});
      expect(prs.containsKey(bench), isFalse);
    });

    test('importerad historik konkurrerar på lika villkor', () {
      final prs = personalRecords([
        entry(d1, [ex(bench, [work(const SetValues(weight: 140, reps: 1))])], source: EntrySource.imported),
        entry(d2, [ex(bench, [work(const SetValues(weight: 120, reps: 3))])]),
      ]);
      expect(prs[bench]!.value, 140);
      expect(prs[bench]!.source, EntrySource.imported);
    });

    test('vilodagar påverkar inte', () {
      final prs = personalRecords([
        RestEntry(date: d3, sessionId: const SessionId('V'), note: 'promenad'),
        entry(d1, [ex(bench, [work(const SetValues(weight: 100, reps: 5))])]),
      ]);
      expect(prs.length, 1);
    });
  });

  group('progression', () {
    test('en punkt per pass, äldst först, med löpande PR-markering', () {
      final pts = progression([
        entry(d3, [ex(bench, [work(const SetValues(weight: 105, reps: 5))])]),
        entry(d1, [ex(bench, [work(const SetValues(weight: 100, reps: 5))])]),
        entry(d2, [ex(bench, [work(const SetValues(weight: 95, reps: 5))])]),
      ], bench);
      expect(pts.map((p) => p.value), [100, 95, 105]);
      expect(pts.map((p) => p.isPr), [true, false, true]);
      expect(pts.last.set.values.weight, 105, reason: 'passets bästa set följer med (grafetiketten)');
    });

    test('PR-markering följer RECORDS: fler reps på samma vikt är också PR', () {
      final pts = progression([
        entry(d1, [ex(bench, [work(const SetValues(weight: 130, reps: 1))])]),
        entry(d2, [ex(bench, [work(const SetValues(weight: 130, reps: 2))])]),
        entry(d3, [ex(bench, [work(const SetValues(weight: 130, reps: 2))])]),
      ], bench);
      expect(pts.map((p) => p.isPr), [true, true, false]);
    });

    test('kroppsviktsövning plottar bara tillagd vikt — viktnedgång straffas inte', () {
      final pts = progression([
        entry(d1, [ex(chins, [work(const SetValues(extra: 10, reps: 5), bw: 100)], m: Measure.bodyweight)]),
        entry(d2, [ex(chins, [work(const SetValues(extra: 10, reps: 5), bw: 95)], m: Measure.bodyweight)]),
      ], chins);
      expect(pts.map((p) => p.value), [10, 10]);
    });
  });

  group('lastPerformance', () {
    test('senaste passet med minst ett loggat arbetsset', () {
      final last = lastPerformance([
        entry(d1, [ex(bench, [work(const SetValues(weight: 100, reps: 5))])]),
        entry(d3, [ex(bench, [warmup(const SetValues(weight: 60, reps: 8))])]),
        entry(d2, [ex(bench, [warmup(const SetValues(weight: 60, reps: 8)), work(const SetValues(weight: 102.5, reps: 5))])]),
      ], bench);
      expect(last!.date, d2);
      expect(last.workSets.single.values.weight, 102.5);
      expect(last.warmupSets.length, 1);
    });

    test('överhoppad övning hoppas över, ingen historik ger null', () {
      expect(lastPerformance([
        entry(d1, [ex(bench, [work(const SetValues(weight: 100, reps: 5))], status: ExerciseStatus.skipped)]),
      ], bench), isNull);
      expect(lastPerformance(const [], bench), isNull);
    });
  });
}
