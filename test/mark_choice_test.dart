import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/ui/chain/chain_strip.dart';

void main() {
  test('pass loggade dag för dag får alla fem varianterna, inte samma hela tiden', () {
    final seen = <int>{};
    final days = <int>[];
    for (var d = 1; d <= 20; d++) {
      final (v, _) = MarkChoice.pick(DateTime(2026, 9, d, 18, 30).millisecondsSinceEpoch);
      seen.add(v);
      days.add(v);
    }
    expect(seen, {0, 1, 2, 3, 4});
    // Aldrig långa rader av samma: högst tre i följd.
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      run = days[i] == days[i - 1] ? run + 1 : 1;
      expect(run, lessThanOrEqualTo(3), reason: '$days');
    }
  });

  test('samma frö = samma variant och samma jitter', () {
    final s = DateTime(2026, 10, 9, 7).millisecondsSinceEpoch;
    final (v1, r1) = MarkChoice.pick(s);
    final (v2, r2) = MarkChoice.pick(s);
    expect(v1, v2);
    expect(r1.nextDouble(), r2.nextDouble());
  });
}
