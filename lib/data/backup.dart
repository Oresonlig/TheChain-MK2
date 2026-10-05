/// Säkerhetskopia: allt i appen som EN JSON-fil — varje tabell, varje post med
/// stämpel, även raderingar (tombstones). Samma form som den lokala lagringen,
/// så en kopia går att läsa tillbaka utan tolkning. Skyddsnät när MK2 blir den
/// enda källan (Niklas 2026-10-03).
library;

import 'dart:convert';

import '../domain/sync.dart';
import 'json_codec.dart';
import 'sync_engine.dart';

const backupFormat = 'thechain-mk2-backup';

Json buildBackup(SyncEngine engine, {required String? email, required DateTime now, required String appVersion}) => {
      'format': backupFormat,
      'v': 1,
      'exportedAt': now.toUtc().toIso8601String(),
      'email': email,
      'appVersion': appVersion,
      'tables': {
        for (final t in engine.tables.values)
          t.table: {
            for (final e in t.items.entries)
              e.key: {
                's': [e.value.stamp.wallMs, e.value.stamp.counter, e.value.stamp.node],
                if (e.value.isDeleted) 'del': true else 'd': e.value.value,
              },
          },
      },
    };

String encodeBackup(Json backup) => const JsonEncoder.withIndent(' ').convert(backup);

/// Vad en återställning skulle göra — visas innan något skrivs.
class RestorePlan {
  RestorePlan(this.puts, {required this.keptNewer, required this.email, required this.exportedAt});

  /// Per tabell: poster att lägga tillbaka (id → data).
  final Map<String, Map<String, Json>> puts;

  /// Poster som ändrats på telefonen EFTER backupen — de behålls.
  final int keptNewer;
  final String? email;
  final String? exportedAt;

  int count(String table) => puts[table]?.length ?? 0;
  bool get isEmpty => puts.values.every((m) => m.isEmpty);
}

class BackupFormatError implements Exception {
  const BackupFormatError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Återställning (Niklas 2026-10-05: export fanns, inläsning saknades).
/// Regeln är appens: INGET försvinner. Det som saknas eller är raderat på
/// telefonen läggs tillbaka; det som ändrats här EFTER backupen behålls;
/// backupens raderingar raderar aldrig något. Bara kända tabeller läses.
RestorePlan planRestore(SyncEngine engine, String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    throw const BackupFormatError('This file is not a The Chain backup.');
  }
  if (decoded is! Map || decoded['format'] != backupFormat) throw const BackupFormatError('This file is not a The Chain backup.');
  final tables = decoded['tables'];
  if (tables is! Map) throw const BackupFormatError('The backup has no data.');
  final puts = <String, Map<String, Json>>{};
  var keptNewer = 0;
  for (final t in engine.tables.values) {
    final items = tables[t.table];
    if (items is! Map) continue;
    final out = <String, Json>{};
    for (final e in items.entries) {
      final v = e.value;
      if (v is! Map || v['del'] == true || v['d'] is! Map || v['s'] is! List) continue;
      final s = v['s'] as List;
      if (s.length < 3 || s[0] is! num || s[1] is! num || s[2] is! String) continue;
      final stamp = Stamp((s[0] as num).toInt(), (s[1] as num).toInt(), s[2] as String);
      final local = t.items[e.key as String];
      if (local == null || local.isDeleted || stamp > local.stamp) {
        // Samma innehåll som redan finns behöver inte skrivas om.
        if (local != null && !local.isDeleted && jsonEncode(local.value) == jsonEncode(v['d'])) continue;
        out[e.key as String] = (v['d'] as Map).cast<String, Object?>();
      } else if (local.stamp > stamp && jsonEncode(local.value) != jsonEncode(v['d'])) {
        keptNewer++;
      }
    }
    puts[t.table] = out;
  }
  return RestorePlan(puts, keptNewer: keptNewer, email: decoded['email'] as String?, exportedAt: decoded['exportedAt'] as String?);
}

/// Skriver planen med NYA stämplar, så att det återställda når servern och
/// andra enheter som vanliga ändringar.
Future<void> applyRestore(SyncEngine engine, RestorePlan plan, DateTime now) async {
  for (final e in plan.puts.entries) {
    await engine[e.key].putAll(e.value, now);
  }
}

/// Filnamn med datum, t.ex. thechain-backup-2026-10-03.json.
String backupFileName(DateTime now) =>
    'thechain-backup-${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';
