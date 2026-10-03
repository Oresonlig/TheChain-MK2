/// Säkerhetskopia: allt i appen som EN JSON-fil — varje tabell, varje post med
/// stämpel, även raderingar (tombstones). Samma form som den lokala lagringen,
/// så en kopia går att läsa tillbaka utan tolkning. Skyddsnät när MK2 blir den
/// enda källan (Niklas 2026-10-03).
library;

import 'dart:convert';

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

/// Filnamn med datum, t.ex. thechain-backup-2026-10-03.json.
String backupFileName(DateTime now) =>
    'thechain-backup-${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';
