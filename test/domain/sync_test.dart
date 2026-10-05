import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';

Stamp s(int ms, [int c = 0, String n = 'a']) => Stamp(ms, c, n);

void main() {
  group('Stamp och klocka', () {
    test('ordning: tid, sedan räknare, sedan enhet', () {
      expect(s(2) > s(1), isTrue);
      expect(s(1, 1) > s(1, 0), isTrue);
      expect(s(1, 0, 'b') > s(1, 0, 'a'), isTrue);
    });

    test('klockan går aldrig bakåt även om väggtiden gör det', () {
      final c = SyncClock('phone');
      final t1 = c.tick(DateTime.fromMillisecondsSinceEpoch(5000));
      final t2 = c.tick(DateTime.fromMillisecondsSinceEpoch(3000)); // klockan ställdes bakåt
      final t3 = c.tick(DateTime.fromMillisecondsSinceEpoch(5000));
      expect(t2 > t1, isTrue);
      expect(t3 > t2, isTrue);
    });

    test('observe: nästa lokala ändring hamnar efter det enheten sett', () {
      final c = SyncClock('phone');
      c.observe(s(9000, 3, 'desktop'));
      final local = c.tick(DateTime.fromMillisecondsSinceEpoch(1000)); // telefonen ligger efter
      expect(local > s(9000, 3, 'desktop'), isTrue);
    });
  });

  // Sammanslagningen (senaste stämpeln vinner, tombstones, MK1 3.38.0 och
  // 3.92.1) testas på den riktiga motorn: test/data/sync_engine_test.dart.
}
