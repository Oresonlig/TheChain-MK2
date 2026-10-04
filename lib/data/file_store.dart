/// Lokal lagring i appens dokumentmapp: en JSON-fil per tabell. Skrivs atomärt
/// (temporär fil + byt namn) så att ett avbrott mitt i aldrig lämnar en trasig
/// fil, och en skrivning i taget per tabell.
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

  /// Pågående skrivning per tabell. Sparningar köas: varje tangenttryck i ett
  /// set sparar utan att vänta, och två samtidiga skrivningar till samma
  /// temporärfil kunde annars blanda innehåll eller krocka i namnbytet (2026-10-04).
  final _writing = <String, Future<void>>{};

  File _file(String table) => File('${dir.path}${Platform.pathSeparator}$table.json');

  @override
  Future<TableState> load(String table) async {
    final f = _file(table);
    if (!await f.exists()) return TableState();
    try {
      return _decode(await f.readAsString());
    } catch (_) {
      // Trasig fil (borde inte hända tack vare atomär skrivning). Börja om —
      // servern har det synkade — men spara undan filen: väntande lokala
      // ändringar ska gå att rädda för hand, aldrig försvinna tyst.
      await f.rename('${f.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      return TableState();
    }
  }

  /// Kastar på allt som inte har rätt form (JSON-fel ELLER typfel).
  TableState _decode(String raw) {
    final j = (jsonDecode(raw) as Map).cast<String, Object?>();
    final items = <String, Synced<Json>>{};
    for (final e in ((j['items'] as Map?) ?? const {}).entries) {
      final m = (e.value as Map).cast<String, Object?>();
      final s = (m['s'] as List).cast<Object?>();
      final stamp = Stamp((s[0] as num).toInt(), (s[1] as num).toInt(), s[2] as String);
      final id = e.key as String;
      items[id] = m['del'] == true ? Synced.deleted(id, stamp) : Synced(id, stamp, (m['d'] as Map).cast<String, Object?>());
    }
    return TableState(
      items: items,
      cursor: (j['cursor'] as num?)?.toInt() ?? 0,
      dirty: ((j['dirty'] as List?) ?? const []).cast<String>().toSet(),
    );
  }

  @override
  Future<void> save(String table, TableState state) {
    // Ögonblicksbild NU (ordningen bevaras), skrivningen när förra är klar.
    final text = jsonEncode(_encode(state));
    final next = (_writing[table] ?? Future<void>.value()).catchError((_) {}).then((_) => _write(table, text));
    _writing[table] = next;
    return next;
  }

  Future<void> _write(String table, String text) async {
    await dir.create(recursive: true);
    final f = _file(table);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(f.path);
  }

  Map<String, Object?> _encode(TableState state) {
    return {
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
  }
}
