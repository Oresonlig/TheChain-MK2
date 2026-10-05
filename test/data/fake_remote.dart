// Simulerad server som beter sig som supabase/001_mk2_schema.sql:
// mk2_push skriver bara om stämpeln är nyare (jämförelse tid, räknare, enhet —
// enhet med "C"-kollation = Dart compareTo), global rev-serie, pull = rev > X.
import 'package:the_chain/data/json_codec.dart';
import 'package:the_chain/data/sync_engine.dart';
import 'package:the_chain/domain/sync.dart';

/// Lokal lagring i minnet (appen använder FileLocalStore).
class InMemoryLocalStore implements LocalStore {
  final _tables = <String, TableState>{};

  @override
  Future<TableState> load(String table) async {
    final s = _tables[table];
    if (s == null) return TableState();
    return TableState(items: {...s.items}, cursor: s.cursor, dirty: {...s.dirty});
  }

  @override
  Future<void> save(String table, TableState state) async {
    _tables[table] = TableState(items: {...state.items}, cursor: state.cursor, dirty: {...state.dirty});
  }
}

class FakeRemote implements Remote {
  final _tables = <String, Map<String, RemoteRow>>{};
  int _rev = 0;
  bool offline = false;
  int pushCalls = 0;

  /// Körs medan en push är "på väg" (för att simulera en ändring under nätanropet).
  Future<void> Function()? duringPush;

  Map<String, RemoteRow> table(String t) => _tables.putIfAbsent(t, () => {});

  @override
  Future<PushResult> push(String t, List<RemoteRow> rows) async {
    if (offline) throw Exception('offline');
    pushCalls++;
    final hook = duringPush;
    duringPush = null;
    if (hook != null) await hook();
    final accepted = <String>[], stale = <String>[];
    for (final r in rows) {
      final cur = table(t)[r.id];
      if (cur == null || r.stamp > cur.stamp) {
        table(t)[r.id] = RemoteRow(id: r.id, stamp: r.stamp, deleted: r.deleted, data: r.deleted ? null : r.data, rev: ++_rev);
        accepted.add(r.id);
      } else {
        stale.add(r.id);
      }
    }
    return PushResult(accepted: accepted, stale: stale);
  }

  @override
  Future<List<RemoteRow>> pull(String t, int sinceRev) async {
    if (offline) throw Exception('offline');
    return table(t).values.where((r) => r.rev > sinceRev).toList()..sort((a, b) => a.rev.compareTo(b.rev));
  }

  /// En annan klient (t.ex. gammal kod) skriver direkt.
  void serverWrite(String t, String id, Json data, Stamp stamp) {
    table(t)[id] = RemoteRow(id: id, stamp: stamp, deleted: false, data: data, rev: ++_rev);
  }

  /// Delar ut ett rev nu men raden syns först senare ([commitLate]) — som en
  /// Postgres-transaktion som blir klar efter en senare.
  int reserveRev() => ++_rev;
  void commitLate(String t, String id, Json data, Stamp stamp, int rev) {
    table(t)[id] = RemoteRow(id: id, stamp: stamp, deleted: false, data: data, rev: rev);
  }
}
