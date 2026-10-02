// Portat från MK1 tests/measures.test.js (prValue/prTiebreak) + en paritetstabell
// mot MK1:s MEASURES. Ändras ett mätsätt i MK2 ska det vara ett medvetet beslut.
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';

SetEntry logged(SetValues v, {bool failed = false, double? bw}) => SetEntry(
      id: const SetId('s1'),
      kind: SetKind.work,
      values: v,
      isLogged: true,
      failed: failed,
      bodyweightKg: bw,
    );

void main() {
  group('paritet mot MK1 MEASURES', () {
    // MK1-namn → (MK2-mätsätt, fält, PR).
    final mk1 = <String, (Measure, List<SetField>, PrMetric)>{
      'weight': (Measure.weight, [SetField.weight, SetField.reps], PrMetric.weight),
      'bw': (Measure.bodyweight, [SetField.extra, SetField.reps], PrMetric.extra),
      'bwreps': (Measure.repsOnly, [SetField.reps], PrMetric.reps),
      'timed': (Measure.timed, [SetField.secs], PrMetric.secs),
      'bwtimed': (Measure.bodyweightTimed, [SetField.extra, SetField.secs], PrMetric.secs),
      'cardio': (Measure.cardio, [SetField.secs, SetField.dist], PrMetric.dist),
      'cardiosprint': (Measure.cardioSprint, [SetField.secs, SetField.dist, SetField.sprints], PrMetric.sprints),
      'run': (Measure.run, [SetField.secs, SetField.dist], PrMetric.pace),
      'runsprint': (Measure.runSprint, [SetField.secs, SetField.dist, SetField.sprints], PrMetric.pace),
      'carry': (Measure.carry, [SetField.weight, SetField.distM], PrMetric.weight),
      'inclinecardio': (Measure.inclineCardio, [SetField.incline, SetField.secs, SetField.dist], PrMetric.dist),
      'sauna': (Measure.sauna, [SetField.temp, SetField.secs], PrMetric.secs),
    };

    test('alla tolv finns och ingen extra', () {
      expect(Measure.values.length, mk1.length);
    });

    for (final e in mk1.entries) {
      test('${e.key} har samma fält och PR', () {
        final (m, fields, pr) = e.value;
        expect(m.fields, fields);
        expect(m.pr, pr);
      });
    }
  });

  group('prValue', () {
    test('weight → vikt', () => expect(Measure.weight.prValue(logged(const SetValues(weight: 100, reps: 5))), 100));
    test('bodyweight → extra + kroppsvikt',
        () => expect(Measure.bodyweight.prValue(logged(const SetValues(extra: 15, reps: 5), bw: 98)), 113));
    test('repsOnly → reps', () => expect(Measure.repsOnly.prValue(logged(const SetValues(reps: 20))), 20));
    test('timed → sekunder', () => expect(Measure.timed.prValue(logged(const SetValues(secs: 45))), 45));
    test('cardio → distans', () => expect(Measure.cardio.prValue(logged(const SetValues(secs: 1200, dist: 8))), 8));
    test('cardioSprint → sprintar',
        () => expect(Measure.cardioSprint.prValue(logged(const SetValues(secs: 600, sprints: 12))), 12));
    test('carry → vikt', () => expect(Measure.carry.prValue(logged(const SetValues(weight: 80, distM: 40))), 80));
    test('sauna → sekunder', () => expect(Measure.sauna.prValue(logged(const SetValues(temp: 90, secs: 900))), 900));
    test('failat set räknas aldrig',
        () => expect(Measure.weight.prValue(logged(const SetValues(weight: 100), failed: true)), isNull));
    test('ej loggat set räknas aldrig', () {
      const s = SetEntry(id: SetId('s'), kind: SetKind.work, values: SetValues(weight: 100, reps: 5));
      expect(Measure.weight.prValue(s), isNull);
    });
    test('tomt fält → null', () => expect(Measure.repsOnly.prValue(logged(SetValues.empty)), isNull));
    test('viktat häng: längre tid vinner även med mindre vikt', () {
      final long = Measure.bodyweightTimed.prValue(logged(const SetValues(secs: 75, extra: 0)))!;
      final heavy = Measure.bodyweightTimed.prValue(logged(const SetValues(secs: 60, extra: 20)))!;
      expect(long, greaterThan(heavy));
    });
  });

  group('prValue — pace', () {
    test('10 km på 50 min = 12 km/h',
        () => expect(Measure.run.prValue(logged(const SetValues(secs: 3000, dist: 10))), closeTo(12, 1e-9)));
    test('runSprint mäts på pace, inte sprintar', () {
      expect(Measure.runSprint.prValue(logged(const SetValues(secs: 1800, dist: 6, sprints: 8))), closeTo(12, 1e-9));
    });
    test('snabbare tid ger högre värde', () {
      final slow = Measure.run.prValue(logged(const SetValues(secs: 3600, dist: 10)))!;
      final fast = Measure.run.prValue(logged(const SetValues(secs: 3000, dist: 10)))!;
      expect(fast, greaterThan(slow));
    });
    test('saknat fält eller noll ger ingen PR', () {
      expect(Measure.run.prValue(logged(const SetValues(secs: 3000))), isNull);
      expect(Measure.run.prValue(logged(const SetValues(dist: 10))), isNull);
      expect(Measure.run.prValue(logged(const SetValues(secs: 0, dist: 10))), isNull);
      expect(Measure.run.prValue(logged(const SetValues(secs: 3000, dist: 0))), isNull);
    });
  });

  group('prTiebreak', () {
    test('vikt lika → reps', () => expect(Measure.weight.prTiebreak(logged(const SetValues(weight: 100, reps: 8))), 8));
    test('tid lika → last', () {
      expect(Measure.timed.prTiebreak(logged(const SetValues(secs: 30, weight: 10, extra: 5))), 15);
      expect(Measure.bodyweightTimed.prTiebreak(logged(const SetValues(secs: 60, extra: 20))),
          greaterThan(Measure.bodyweightTimed.prTiebreak(logged(const SetValues(secs: 60, extra: 5)))));
    });
    test('sprintar → ingen tiebreak', () => expect(Measure.cardioSprint.prTiebreak(logged(const SetValues(sprints: 5))), 0));
    test('pace lika → längre distans', () => expect(Measure.run.prTiebreak(logged(const SetValues(secs: 3000, dist: 10))), 10));
  });
}
