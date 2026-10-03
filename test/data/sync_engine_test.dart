import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/data/sync_engine.dart';
import 'package:the_chain/domain/sync.dart';

import 'fake_remote.dart';

DateTime at(int s) => DateTime.fromMillisecondsSinceEpoch(1790000000000 + s * 1000);
const bw = Tables.bodyweight;

Future<SyncEngine> device(FakeRemote server, String id, [LocalStore? store]) async {
  final e = SyncEngine(remote: server, store: store ?? InMemoryLocalStore(), deviceId: id);
  await e.open();
  return e;
}

void main() {
  test('offline-ändring sparas lokalt och skickas vid nästa sync', () async {
    final server = FakeRemote()..offline = true;
    final phone = await device(server, 'phone');
    await phone[bw].put('2026-10-02', {'kg': 100.3}, at(1));
    final r1 = await phone[bw].sync();
    expect(r1.outcome, SyncOutcome.pushBlockedByGate);
    expect(phone[bw].pendingCount, 1);
    server.offline = false;
    final r2 = await phone[bw].sync();
    expect(r2.outcome, SyncOutcome.ok);
    expect(phone[bw].pendingCount, 0);
    expect(server.table(bw)['2026-10-02']!.data, {'kg': 100.3});
  });

  test('ändring MEDAN push pågår ligger kvar som väntande och skickas sen', () async {
    final server = FakeRemote();
    final phone = await device(server, 'phone');
    await phone[bw].put('d', {'kg': 100}, at(1));
    server.duringPush = () => phone[bw].put('d', {'kg': 101}, at(2));
    await phone[bw].sync();
    expect(server.table(bw)['d']!.data, {'kg': 100}); // pushen skickade den äldre
    expect(phone[bw].pendingCount, 1, reason: 'den nyare får inte kvitteras som skickad');
    await phone[bw].sync();
    expect(server.table(bw)['d']!.data, {'kg': 101});
    expect(phone[bw].pendingCount, 0);
  });

  test('LÄS FÖRE SKRIV: ingen push innan en lyckad pull denna session', () async {
    final server = FakeRemote()..offline = true;
    final phone = await device(server, 'phone');
    await phone[bw].put('d', {'kg': 1}, at(1));
    await phone[bw].sync();
    expect(server.pushCalls, 0);
    expect(phone[bw].hasPulled, isFalse);
  });

  test('två enheter konvergerar; senaste ändringen vinner', () async {
    final server = FakeRemote();
    final phone = await device(server, 'phone');
    final web = await device(server, 'tablet');
    await phone[bw].put('2026-10-02', {'kg': 100.3}, at(1));
    await phone[bw].sync();
    await web[bw].sync();
    expect(web[bw].items['2026-10-02']!.value, {'kg': 100.3});
    await web[bw].put('2026-10-02', {'kg': 99.8}, at(5)); // MK1 3.92.1-scenariot
    await web[bw].sync();
    final r = await phone[bw].sync();
    expect(r.localChanged, isTrue);
    expect(phone[bw].items['2026-10-02']!.value, {'kg': 99.8});
  });

  test('servern avvisar äldre skrivning; klienten hämtar nyare och släpper sin', () async {
    final server = FakeRemote();
    final phone = await device(server, 'phone');
    await phone[bw].sync();
    await phone[bw].put('d', {'kg': 100}, at(1));
    server.serverWrite(bw, 'd', {'kg': 97}, Stamp(at(9).millisecondsSinceEpoch, 0, 'tablet'));
    final r = await phone[bw].sync();
    expect(r.outcome, SyncOutcome.ok);
    expect(phone[bw].items['d']!.value, {'kg': 97});
    expect(phone[bw].pendingCount, 0);
    expect(server.table(bw)['d']!.data, {'kg': 97});
  });

  test('radering sprids och återuppstår inte från en enhet med gammal kopia', () async {
    final server = FakeRemote();
    final phone = await device(server, 'phone');
    final tablet = await device(server, 'tablet');
    await phone[Tables.notes].put('n1', {'text': 'old'}, at(1));
    await phone[Tables.notes].sync();
    await tablet[Tables.notes].sync();
    await phone[Tables.notes].remove('n1', at(5));
    await phone[Tables.notes].sync();
    // surfplattan försöker skicka sin gamla kopia igen (t.ex. efter att ha varit offline)
    await tablet[Tables.notes].put('n1', {'text': 'old'}, at(3));
    await tablet[Tables.notes].sync();
    expect(tablet[Tables.notes].items['n1']!.isDeleted, isTrue);
    expect(server.table(Tables.notes)['n1']!.deleted, isTrue);
  });

  test('lokalt läge överlever omstart (markör, väntande ändringar, klocka)', () async {
    final server = FakeRemote()..offline = true;
    final store = InMemoryLocalStore();
    final a = await device(server, 'phone', store);
    await a[bw].put('d', {'kg': 1}, at(10));
    final b = await device(server, 'phone', store); // appen startas om
    expect(b[bw].pendingCount, 1);
    final next = b.clock.tick(at(0)); // väggklockan "bakåt" efter omstart
    expect(next > b[bw].items['d']!.stamp, isTrue);
  });

  test('hämtning är inkrementell: bara nya rader efter markören', () async {
    final server = FakeRemote();
    final phone = await device(server, 'phone');
    final tablet = await device(server, 'tablet');
    await tablet[bw].put('a', {'kg': 1}, at(1));
    await tablet[bw].sync();
    await phone[bw].sync();
    final first = await server.pull(bw, 0);
    expect(first.length, 1);
    await tablet[bw].put('b', {'kg': 2}, at(2));
    await tablet[bw].sync();
    final r = await phone[bw].sync();
    expect(r.pulled, 1);
    expect(phone[bw].liveValues.length, 2);
  });

  test('syncAll kör alla sex tabellerna', () async {
    final server = FakeRemote();
    final phone = await device(server, 'phone');
    final reports = await phone.syncAll();
    expect(reports.keys.toSet(), Tables.all.toSet());
    expect(reports.values.every((r) => r.outcome == SyncOutcome.ok), isTrue);
  });
}
