// Paritet mot en RIKTIG MK1-backup (test/fixtures/private/*.json, gitignorerad —
// repot är publikt). Saknas filen (CI) hoppas testet över. Skriver ut en
// sammanfattning, inga persondata.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';
import 'package:the_chain/mk1/mk1_codec.dart';

File? _backup() {
  final dir = Directory('test/fixtures/private');
  if (!dir.existsSync()) return null;
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
  return files.isEmpty ? null : files.first;
}

void main() {
  final file = _backup();
  final raw = file == null ? null : (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();

  test('riktig backup: allt följer med och PR stämmer mot MK1:s regler', () {
    if (raw == null) {
      markTestSkipped('Ingen privat backup');
      return;
    }
    final snap = decodeMk1(raw);
    final log = (raw['log'] as List? ?? const []).cast<Map<String, Object?>>();
    final workouts = snap.history.whereType<WorkoutEntry>().toList();
    final rests = snap.history.whereType<RestEntry>().toList();

    // 1. Inga pass försvinner (utom de som varnas för).
    expect(workouts.length + snap.warnings.where((w) => w.startsWith('log[')).length, log.length);

    // 2. Antal set per pass bevaras.
    var mk1Sets = 0, mk2Sets = 0;
    for (final e in log) {
      for (final ex in (e['exercises'] as List? ?? const []).cast<Map<String, Object?>>()) {
        mk1Sets += (ex['sets'] as List? ?? const []).length;
      }
    }
    for (final w in workouts) {
      for (final ex in w.workout.exercises) {
        mk2Sets += ex.sets.length;
      }
    }
    expect(mk2Sets, mk1Sets);

    // 3. PR per övning: MK1:s getAllPRs-regel räknad direkt på JSON:en.
    final mk1Best = <String, double>{};
    for (final w in workouts) {
      for (final ex in w.workout.exercises) {
        if (ex.status == ExerciseStatus.skipped) continue;
        for (final s in ex.sets.where((s) => s.kind == SetKind.work)) {
          final v = _mk1PrValue(ex.measure, s);
          if (v == null) continue;
          final k = ex.exerciseId.value;
          if (v > (mk1Best[k] ?? double.negativeInfinity)) mk1Best[k] = v;
        }
      }
    }
    final mk2 = personalRecords(snap.history);
    final diffs = <String>[];
    for (final e in mk1Best.entries) {
      final v2 = mk2[ExerciseId(e.key)]?.value;
      if (v2 == null || (v2 - e.value).abs() > 1e-9) diffs.add('${e.key}: MK1 ${e.value} / MK2 $v2');
    }

    // 4. Övningar som inte känns igen (varken bibliotek eller egna).
    final unknown = <String>{
      for (final w in workouts)
        for (final ex in w.workout.exercises)
          if (libraryExercise(ex.exerciseId) == null && !snap.custom.containsKey(ex.exerciseId)) ex.exerciseId.value,
    };

    final offset = snap.roundOffsetFor(snap.program);
    final round = chainState(snap.program, snap.history, manualRestarts: snap.manualRestarts, roundOffset: offset).round;

    // ignore: avoid_print
    print('''
── Riktig backup ─────────────────────────────
Pass: ${workouts.length} · vilodagar: ${rests.length} · set: $mk2Sets
PR: MK2 ${mk2.length} övningar · MK1-regeln ${mk1Best.length} · skillnader: ${diffs.length}
${diffs.take(10).join('\n')}
Program: ${snap.program.sessions.map((s) => s.id.value).join(' ')}
Round: MK1 ${snap.mk1Round} · MK2 $round (offset $offset)
Vikt: ${snap.bodyweight.length} · anteckningar: ${snap.notes.length} · egna övningar: ${snap.custom.length} · justeringar: ${snap.overrides.length}
Okända övnings-id (${unknown.length}): ${unknown.take(15).join(', ')}
Varningar (${snap.warnings.length}): ${snap.warnings.take(10).join(' | ')}
──────────────────────────────────────────────''');

    expect(diffs, isEmpty, reason: 'PR skiljer sig mellan MK1-regeln och MK2');
    expect(round, snap.mk1Round);
  });
}

/// MK1:s prValue (index.html) — inklusive att den INTE kräver reps för vikt.
/// MK2 kräver minst en rep (beslut 2026-10-02); skillnader rapporteras.
double? _mk1PrValue(Measure m, SetEntry s) {
  if (s.excludeFromRecords) return null;
  final v = s.values;
  return switch (m.pr) {
    PrMetric.weight => v.weight,
    PrMetric.extra => v.extra == null ? null : v.extra! + (s.bodyweightKg ?? 0),
    PrMetric.reps => v.reps?.toDouble(),
    PrMetric.secs => v.secs?.toDouble(),
    PrMetric.dist => v.dist,
    PrMetric.sprints => v.sprints?.toDouble(),
    PrMetric.pace => (v.dist != null && v.dist! > 0 && v.secs != null && v.secs! > 0) ? v.dist! / (v.secs! / 3600) : null,
  };
}
