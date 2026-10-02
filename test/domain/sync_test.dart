import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';

Stamp s(int ms, [int c = 0, String n = 'a']) => Stamp(ms, c, n);
Map<String, Synced<String>> m(List<Synced<String>> xs) => {for (final x in xs) x.id: x};

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

  group('mergeSynced', () {
    test('senaste stämpeln vinner per post, åt båda håll', () {
      final r = mergeSynced(
        m([Synced('w', s(10), 'lokal-ny'), Synced('x', s(1), 'lokal-gammal')]),
        m([Synced('w', s(5), 'moln-gammal'), Synced('x', s(7), 'moln-ny')]),
      );
      expect(r.merged['w']!.value, 'lokal-ny');
      expect(r.merged['x']!.value, 'moln-ny');
      expect(r.localChanged, isTrue);
      expect(r.remoteBehind, isTrue);
    });

    test('poster som bara finns på ena sidan behålls', () {
      final r = mergeSynced(m([Synced('a', s(1), 'A')]), m([Synced('b', s(1), 'B')]));
      expect(r.merged.keys, unorderedEquals(['a', 'b']));
    });

    test('kommutativ: samma resultat oavsett vilken enhet som slår ihop', () {
      final a = m([Synced('w', s(5, 0, 'phone'), 'P'), Synced('n', s(2), 'x')]);
      final b = m([Synced('w', s(5, 0, 'desk'), 'D'), Synced.deleted('n', s(3))]);
      final ab = mergeSynced(a, b).merged, ba = mergeSynced(b, a).merged;
      for (final id in ab.keys) {
        expect(ab[id]!.stamp, ba[id]!.stamp);
        expect(ab[id]!.value, ba[id]!.value);
      }
    });

    test('idempotent: att slå ihop med sig själv ändrar ingenting', () {
      final a = m([Synced('w', s(5), 'P')]);
      final r = mergeSynced(a, a);
      expect(r.localChanged, isFalse);
      expect(r.remoteBehind, isFalse);
    });

    test('MK1 3.38.0: raderad anteckning återuppstår inte från gammal kopia', () {
      final r = mergeSynced(
        m([Synced.deleted('note1', s(20))]),
        m([Synced('note1', s(10), 'gammal anteckning')]),
      );
      expect(r.merged['note1']!.isDeleted, isTrue);
    });

    test('en ändring EFTER raderingen är en legitim återskapning', () {
      final r = mergeSynced(
        m([Synced.deleted('note1', s(20))]),
        m([Synced('note1', s(30), 'ny')]),
      );
      expect(r.merged['note1']!.value, 'ny');
    });

    test('MK1 3.92.1: ändrad kroppsvikt på hemsidan når appen (lokalt vinner inte alltid)', () {
      final app = m([Synced('2026-09-30', s(100, 0, 'app'), '100.3')]);
      final web = m([Synced('2026-09-30', s(200, 0, 'web'), '99.8')]);
      final r = mergeSynced(app, web);
      expect(r.merged['2026-09-30']!.value, '99.8');
      expect(r.localChanged, isTrue);
    });
  });

  group('purgeTombstones', () {
    test('rensar bara tombstones äldre än TTL, aldrig levande poster', () {
      final now = DateTime.fromMillisecondsSinceEpoch(200 * 86400000);
      final old = 10 * 86400000, recent = 190 * 86400000;
      final out = purgeTombstones(
        m([
          Synced.deleted('gammal', Stamp(old, 0, 'a')),
          Synced.deleted('ny', Stamp(recent, 0, 'a')),
          Synced('levande', Stamp(old, 0, 'a'), 'kvar'),
        ]),
        now,
      );
      expect(out.keys, unorderedEquals(['ny', 'levande']));
    });
  });
}
