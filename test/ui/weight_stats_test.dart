import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';
import 'package:the_chain/ui/charts/chart_data.dart';
import 'package:the_chain/ui/charts/series.dart';

void main() {
  const kg = UserSettings(weightGoalKg: 95);
  final entries = [
    for (var d = 1; d <= 20; d++) BodyweightEntry(date: '2026-09-${d.toString().padLeft(2, '0')}', kg: 100.0 - d * 0.1),
    const BodyweightEntry(date: '2026-09-23', kg: 96.0), // efter 72 h fasta
  ];

  test('NOW och TO GOAL följer senaste vägningen — inte trenden', () {
    final s = weightStats(entries, kg)!;
    expect(s.now, '96 kg');
    expect(s.toGoal, '−1 kg');
  });

  test('7 DAYS räknas på trenden: fastans hopp slår inte igenom fullt', () {
    final s = weightStats(entries, kg)!;
    // Vågen föll ~2 kg på en vecka, trenden betydligt mindre.
    expect(s.week, startsWith('−'));
    final v = double.parse(s.week!.substring(1).split(' ').first);
    expect(v, lessThan(1.5));
  });

  test('inget mål → TO GOAL saknas; lbs visas i lbs', () {
    expect(weightStats(entries, const UserSettings())!.toGoal, isNull);
    expect(weightStats(entries, const UserSettings(weightUnit: WeightUnit.lbs))!.now, '211.6 lbs');
  });

  test('egen period: bara april, förändringen märkt med datumen', () {
    final apr = [
      const BodyweightEntry(date: '2026-03-25', kg: 101),
      const BodyweightEntry(date: '2026-04-01', kg: 100),
      const BodyweightEntry(date: '2026-04-30', kg: 97),
      const BodyweightEntry(date: '2026-05-10', kg: 96),
    ];
    final w = ChartWindow(DateTime(2026, 4, 1), DateTime(2026, 4, 30), windowLabel(DateTime(2026, 4, 1), DateTime(2026, 4, 30), DateTime(2026, 10, 3)));
    final series = weightSeries(apr, w, const UserSettings());
    expect(series.dots.map((p) => p.y), [100, 97]);
    expect(weightChange(series, w, const UserSettings()), endsWith('· 1 Apr–30 Apr'));
  });
}
