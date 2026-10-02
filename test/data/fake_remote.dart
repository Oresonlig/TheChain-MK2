// Simulerad server som beter sig som supabase/001_mk2_schema.sql:
// mk2_push skriver bara om stämpeln är nyare (jämförelse tid, räknare, enhet —
// enhet med "C"-kollation = Dart compareTo), global rev-serie, pull = rev > X.
import 'package:the_chain/data/json_codec.dart';
import 'package:the_chain/data/sync_engine.dart';
import 'package:the_chain/domain/sync.dart';

class FakeRemote implements Remote {
  final _tables = <String, Map<String, RemoteRow>>{};
  int _rev = 0;
  bool offline = false;
  int pushCalls = 0;

  Map<String, RemoteRow> table(String t) => _tables.putIfAbsent(t, () => {});

  @override
  Future<PushResult> push(String t, List<RemoteRow> rows) async {
    if (offline) throw Exception('offline');
    pushCalls++;
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
}
