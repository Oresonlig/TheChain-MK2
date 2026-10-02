import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';

const a = SessionId('A'), b = SessionId('B'), c = SessionId('C'), v = SessionId('V');
const program = Program(sessions: [
  Session(id: a, name: 'Chest'),
  Session(id: b, name: 'Back'),
  Session(id: v, name: 'Rest', kind: SessionKind.rest),
  Session(id: c, name: 'Legs'),
]);

var _n = 0;
DateTime day(int d) => DateTime(2026, 9, d);

HistoryEntry trained(SessionId s, int d, {EntrySource source = EntrySource.app}) => WorkoutEntry(
      source: source,
      workout: Workout(id: WorkoutId('w${_n++}'), sessionId: s, startedAt: day(d), finishedAt: day(d)),
    );
HistoryEntry rested(SessionId s, int d) => RestEntry(date: day(d), sessionId: s);

void main() {
  test('tom historik: runda 1, nästa = första passet', () {
    final st = chainState(program, const []);
    expect(st.round, 1);
    expect(st.done, isEmpty);
    expect(st.next, a);
  });

  test('i ordning: nästa = första ej avklarade', () {
    final st = chainState(program, [trained(a, 1), trained(b, 2)]);
    expect(st.done, {a, b});
    expect(st.next, v);
  });

  test('bröstpasset före ryggen: ryggen föreslås fortfarande', () {
    // Träningskamraten ville köra C (ben) fast A var på tur.
    final st = chainState(program, [trained(c, 1)]);
    expect(st.done, {c});
    expect(st.next, a);
  });

  test('cykeln stängs när alla pass inkl. vilodag är gjorda, oavsett ordning', () {
    final st = chainState(program, [trained(c, 1), rested(v, 2), trained(b, 3), trained(a, 4)]);
    expect(st.round, 2);
    expect(st.done, isEmpty);
    expect(st.next, a);
  });

  test('samma pass två gånger i en cykel räknas en gång', () {
    final st = chainState(program, [trained(a, 1), trained(a, 2), trained(b, 3)]);
    expect(st.done, {a, b});
    expect(st.round, 1);
  });

  test('ordning i listan spelar ingen roll — sorteras på datum', () {
    final st = chainState(program, [trained(a, 4), trained(c, 1), trained(b, 3), rested(v, 2), trained(a, 5)]);
    expect(st.round, 2);
    expect(st.done, {a});
  });

  test('manuell omstart stänger pågående cykel', () {
    final st = chainState(program, [trained(a, 1), trained(b, 2), trained(c, 5)],
        manualRestarts: [day(3)]);
    expect(st.round, 2);
    expect(st.done, {c});
  });

  test('roundOffset fortsätter MK1:s räknare', () {
    final st = chainState(program, [trained(a, 1)], roundOffset: 17);
    expect(st.round, 18);
  });

  test('importerad historik och borttagna pass räknas inte', () {
    final st = chainState(program, [
      trained(a, 1, source: EntrySource.imported),
      trained(const SessionId('X'), 2),
      trained(b, 3),
    ]);
    expect(st.done, {b});
    expect(st.next, a);
  });

  test('tomt program: ingen nästa, ingen oändlig cykel', () {
    final st = chainState(const Program(sessions: []), [trained(a, 1)]);
    expect(st.next, isNull);
    expect(st.round, 1);
  });
}
