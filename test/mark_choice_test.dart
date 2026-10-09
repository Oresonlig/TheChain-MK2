import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/ui/chain/chain_strip.dart';

void main() {
  tearDown(() => MarkChoice.forced = null);

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

  test('DEV-knappen: 1 → 5 på alla, sedan AUTO', () {
    final s = DateTime(2026, 10, 9).millisecondsSinceEpoch;
    final steps = <int?>[];
    for (var i = 0; i < 6; i++) {
      MarkChoice.cycle();
      steps.add(MarkChoice.forced);
    }
    expect(steps, [0, 1, 2, 3, 4, null]);
    MarkChoice.forced = 3;
    expect(MarkChoice.pick(s).$1, 3);
    expect(ScarPainter(const Color(0xFF000000), seed: s).shouldRepaint(ScarPainter(const Color(0xFF000000), seed: s)),
        isFalse);
    final before = ScarPainter(const Color(0xFF000000), seed: s);
    MarkChoice.cycle();
    expect(ScarPainter(const Color(0xFF000000), seed: s).shouldRepaint(before), isTrue, reason: 'knappen ritar om');
  });
}
