/// Riktiga servern: Supabase-tabellerna och mk2_push (supabase/001_mk2_schema.sql).
/// Testas mot FakeRemote med samma semantik; verifieras på riktigt när schemat körts.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/sync.dart';
import 'sync_engine.dart';

class SupabaseRemote implements Remote {
  SupabaseRemote(this.client);

  final SupabaseClient client;
  static const _page = 1000;

  @override
  Future<PushResult> push(String table, List<RemoteRow> rows) async {
    if (rows.isEmpty) return const PushResult(accepted: [], stale: []);
    final accepted = <String>[], stale = <String>[];
    // mk2_push tar max 500 rader per anrop.
    for (var i = 0; i < rows.length; i += 500) {
      final chunk = rows.sublist(i, i + 500 > rows.length ? rows.length : i + 500);
      final res = await client.rpc<Object?>('mk2_push', params: {
        'p_table': table,
        'p_rows': [
          for (final r in chunk)
            {
              'id': r.id,
              'stamp_ms': r.stamp.wallMs,
              'stamp_counter': r.stamp.counter,
              'stamp_node': r.stamp.node,
              'deleted': r.deleted,
              'data': r.data,
            },
        ],
      });
      final m = (res as Map).cast<String, Object?>();
      accepted.addAll(((m['accepted'] as List?) ?? const []).cast<String>());
      stale.addAll(((m['stale'] as List?) ?? const []).cast<String>());
    }
    return PushResult(accepted: accepted, stale: stale);
  }

  @override
  Future<List<RemoteRow>> pull(String table, int sinceRev) async {
    final out = <RemoteRow>[];
    var since = sinceRev;
    while (true) {
      final rows = await client
          .from(table)
          .select('id,stamp_ms,stamp_counter,stamp_node,deleted,data,rev')
          .gt('rev', since)
          .order('rev')
          .limit(_page);
      for (final r in rows) {
        out.add(RemoteRow(
          id: r['id'] as String,
          stamp: Stamp((r['stamp_ms'] as num).toInt(), (r['stamp_counter'] as num).toInt(), r['stamp_node'] as String),
          deleted: r['deleted'] == true,
          data: r['data'] == null ? null : (r['data'] as Map).cast<String, Object?>(),
          rev: (r['rev'] as num).toInt(),
        ));
      }
      if (rows.length < _page) break;
      since = out.last.rev;
    }
    return out;
  }
}
