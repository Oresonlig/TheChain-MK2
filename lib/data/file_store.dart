/// Lokal lagring i appens dokumentmapp: en JSON-fil per tabell. Skrivs atomärt
/// (temporär fil + byt namn) så att ett avbrott mitt i aldrig lämnar en trasig fil.
library;

import 'dart:convert';
import 'dart:io';

import '../domain/sync.dart';
import 'json_codec.dart';
import 'sync_engine.dart';

class FileLocalStore implements LocalStore {
  FileLocalStore(this.dir);

  /// Mappen filerna ligger i (per inloggad användare).
  final Directory dir;

  File _file(String table) => File('${dir.path}${Platform.pathSeparator}$table.json');

  @override
  Future<TableState> load(String table) async {
    final f = _file(table);
    if (!await f.exists()) return TableState();
    try {
      final j = (jsonDecode(await f.readAsString()) as Map).cast<String, Object?>();
      final items = <String, Synced<Json>>{};
      for (final e in ((j['items'] as Map?) ?? const {}).entries) {
        final m = (e.value as Map).cast<String, Object?>();
        final s = (m['s'] as List).cast<Object?>();
        final stamp = Stamp((s[0] as num).toInt(), (s[1] as num).toInt(), s[2] as String);
        final id = e.key as String;
        items[id] = m['del'] == true
            ? Synced.deleted(id, stamp)
            : Synced(id, stamp, (m['d'] as Map).cast<String, Object?>());
      }
      return TableState(
        items: items,
        cursor: (j['cursor'] as num?)?.toInt() ?? 0,
        dirty: ((j['dirty'] as List?) ?? const []).cast<String>().toSet(),
      );
    } on FormatException {
      // Trasig fil (borde inte hända tack vare atomär skrivning). Börja om —
      // servern har datan; väntande lokala ändringar kan inte räddas ur skräp.
      return TableState();
    }
  }

  @override
  Future<void> save(String table, TableState state) async {
    await dir.create(recursive: true);
    final j = {
      'cursor': state.cursor,
      'dirty': state.dirty.toList(),
      'items': {
        for (final e in state.items.entries)
          e.key: {
            's': [e.value.stamp.wallMs, e.value.stamp.counter, e.value.stamp.node],
            if (e.value.isDeleted) 'del': true else 'd': e.value.value,
          },
      },
    };
    final f = _file(table);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(j), flush: true);
    await tmp.rename(f.path);
  }
}
