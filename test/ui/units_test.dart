import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';
import 'package:the_chain/ui/units.dart';

const kg = UserSettings(), lbs = UserSettings(weightUnit: WeightUnit.lbs, tempUnit: TempUnit.fahrenheit);
SetEntry s(SetValues v, {SetValues? target}) =>
    SetEntry(id: const SetId('s'), kind: SetKind.work, values: v, target: target, isLogged: true);

void main() {
  test('fält per mätsätt, +F bara där det är meningsfullt', () {
    expect(inputFields(Measure.weight), [InputField.weight, InputField.reps, InputField.forced]);
    expect(inputFields(Measure.cardio), [InputField.secs, InputField.dist]);
    expect(fieldLabel(InputField.secs, Measure.cardio, kg), 'MIN');
    expect(fieldLabel(InputField.secs, Measure.timed, kg), 'SEC');
  });

  test('lbs, minuter och °F: visas i användarens enhet, lagras metriskt', () {
    var v = applyInput(InputField.weight, '220,5', SetValues.empty, Measure.weight, lbs);
    expect(v.weight, closeTo(100.0, 0.05));
    expect(displayValue(InputField.weight, v, Measure.weight, lbs), '220.5');
    v = applyInput(InputField.secs, '32.5', SetValues.empty, Measure.cardio, kg);
    expect(v.secs, 1950);
    expect(displayValue(InputField.secs, v, Measure.cardio, kg), '32.5');
    v = applyInput(InputField.temp, '194', SetValues.empty, Measure.sauna, lbs);
    expect(v.temp, closeTo(90, 0.01));
    expect(applyInput(InputField.reps, '', const SetValues(reps: 5), Measure.weight, kg).reps, isNull);
  });

  test('set på en rad, med missat mål och +F', () {
    expect(fmtSet(s(const SetValues(weight: 100, reps: 3, forcedReps: 1), target: const SetValues(reps: 4)), Measure.weight, kg),
        '100 kg × 3/4 +1');
    expect(fmtSet(s(const SetValues(extra: 10, secs: 60)), Measure.bodyweightTimed, kg), 'BW + 10 kg · 60 s');
    expect(fmtSet(s(const SetValues(secs: 1950, dist: 5.2)), Measure.cardio, kg), '32.5 min · 5.2 km');
    expect(fmtSet(s(const SetValues(temp: 90, secs: 900)), Measure.sauna, kg), '90 °C · 15 min');
    expect(fmtSet(s(const SetValues(reps: 12)), Measure.repsOnly, kg), '12 reps');
  });

  test('dagar sedan', () {
    final now = DateTime(2026, 10, 2, 9);
    expect(daysAgo(DateTime(2026, 10, 2, 1), now), 'today');
    expect(daysAgo(DateTime(2026, 10, 1, 23), now), 'yesterday');
    expect(daysAgo(DateTime(2026, 9, 14), now), '18d ago');
  });
}
