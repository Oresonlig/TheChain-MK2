import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/ui/charts/chart_data.dart';

void main() {
  final now = DateTime(2026, 10, 3, 15);

  test('intervallens start', () {
    expect(ChartRange.m1.start(now), DateTime(2026, 9, 3));
    expect(ChartRange.m3.start(now), DateTime(2026, 7, 3));
    expect(ChartRange.ytd.start(now), DateTime(2026));
    expect(ChartRange.y1.start(now), DateTime(2025, 10, 3));
    expect(ChartRange.all.start(now), isNull);
  });

  group('bästa hittills', () {
    final pts = [
      ChartPoint(DateTime(2026, 1, 1), 100, highlight: true),
      ChartPoint(DateTime(2026, 3, 1), 130, highlight: true),
      ChartPoint(DateTime(2026, 5, 1), 65),
      ChartPoint(DateTime(2026, 9, 20), 70),
    ];

    test('ett steg per PR', () {
      expect(bestSoFarSteps(pts, ChartWindow.of(ChartRange.all, now)).map((p) => p.y), [100, 130]);
    });

    test('PR före fönstret syns ändå — som första steget vid fönstrets första pass', () {
      final steps = bestSoFarSteps(pts, ChartWindow.of(ChartRange.m1, now));
      expect(steps.single.y, 130);
      expect(steps.single.x, DateTime(2026, 9, 20));
    });

    test('x-axeln följer datan, inte fönstret', () {
      final m1 = ChartWindow.of(ChartRange.m1, now);
      final dots = inWindow(pts, (p) => p.x, m1);
      expect(dataSpan(dots, m1), (DateTime(2026, 9, 20), DateTime(2026, 9, 20)));
      expect(dataSpan(pts, ChartWindow.of(ChartRange.all, now)), (DateTime(2026, 1, 1), DateTime(2026, 9, 20)));
      expect(dataSpan(const [], m1), (m1.to, m1.to));
    });

    test('egen period: bara den, slutdagen inräknad; PR efter perioden räknas inte', () {
      final feb = ChartWindow(DateTime(2026, 2, 1), DateTime(2026, 3, 1), 'Feb');
      expect(inWindow(pts, (p) => p.x, feb).map((p) => p.y), [130]);
      expect(bestSoFarSteps(pts, feb).map((p) => p.y), [100, 130]);
    });
  });

  test('trend: följer långsamt, mer ju längre sedan förra vägningen', () {
    final t = trendLine([
      ChartPoint(DateTime(2026, 9, 1), 90),
      ChartPoint(DateTime(2026, 9, 2), 100), // 1 dag: liten dragning
      ChartPoint(DateTime(2026, 12, 1), 80), // 90 dagar: nästan hela vägen
    ]);
    expect(t[0].y, 90);
    expect(t[1].y, closeTo(90.49, .01));
    expect(t[2].y, closeTo(80, .2));
  });

  test('jämna axelsteg', () {
    expect(niceTicks(62, 138), [80, 100, 120]);
    expect(niceTicks(84.3, 91.7), [86, 88, 90]);
  });

  test('y-intervall med marginal; ett enda värde får ändå höjd', () {
    final s = ChartSeries(
      dots: [ChartPoint(DateTime(2026), 100)],
      line: const [],
      from: DateTime(2026),
      to: DateTime(2026, 2),
      formatY: (v) => '$v',
    );
    final (lo, hi) = s.yRange;
    expect(lo, lessThan(100));
    expect(hi, greaterThan(100));
  });
}
