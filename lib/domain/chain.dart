/// Kedjan och cyklerna, härledda ur historiken (Gör om #9, beslut 6).
/// Passordningen är ett FÖRSLAG: vilket pass som helst kan köras, "nästa" är
/// första ej avklarade passet i programordning, och cykeln är klar när alla
/// pass (vilodagar inräknade) är gjorda — oavsett ordning (beslut 2026-10-02).
/// Ett överhoppat pass (med anledning, 2026-10-04) räknas som hanterat.
library;

import 'history.dart';
import 'ids.dart';
import 'program.dart';

class ChainState {
  const ChainState({required this.round, required this.done, required this.next, this.skipped = const {}});

  /// Pågående cykel, 1-baserad ("Round 18").
  final int round;

  /// Avklarade (genomförda) pass i pågående cykel.
  final Set<SessionId> done;

  /// Överhoppade pass i pågående cykel — hanterade, men inte gjorda.
  /// Disjunkt från [done]: tränas ett överhoppat pass ändå vinner "gjort".
  final Set<SessionId> skipped;

  /// Föreslaget nästa pass; null om programmet är tomt.
  final SessionId? next;

  bool isDone(SessionId id) => done.contains(id);
  bool isSkipped(SessionId id) => skipped.contains(id);
}

/// Räknar fram kedjans läge.
///
/// [manualRestarts]: tidpunkter då användaren själv startat om kedjan — allt
/// före en omstart hör till tidigare cykler. [roundOffset]: avslutade cykler
/// före historikens början (t.ex. MK1:s räknare vid övergången).
/// Importerad historik och pass som inte längre finns i programmet räknas inte.
ChainState chainState(
  Program program,
  Iterable<HistoryEntry> history, {
  Iterable<DateTime> manualRestarts = const [],
  int roundOffset = 0,
}) {
  final all = program.sessions.map((s) => s.id).toSet();
  final restarts = manualRestarts.toList()..sort();
  final entries = history.where((e) => e.source == EntrySource.app).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  var completed = roundOffset;
  var done = <SessionId>{};
  var skipped = <SessionId>{};
  var r = 0;

  void closeCycle() {
    completed++;
    done = <SessionId>{};
    skipped = <SessionId>{};
  }

  for (final e in entries) {
    // Omstarter före den här posten stänger pågående cykel (om den har innehåll).
    while (r < restarts.length && !restarts[r].isAfter(e.date)) {
      if (done.isNotEmpty || skipped.isNotEmpty) closeCycle();
      r++;
    }
    final (id, isSkip) = switch (e) {
      WorkoutEntry(:final workout) => (workout.sessionId, false),
      RestEntry(:final sessionId) => (sessionId, false),
      SkippedEntry(:final sessionId) => (sessionId, true),
    };
    if (!all.contains(id)) continue;
    if (isSkip) {
      if (!done.contains(id)) skipped.add(id);
    } else {
      skipped.remove(id);
      done.add(id);
    }
    if (all.isNotEmpty && done.length + skipped.length == all.length) closeCycle();
  }
  while (r < restarts.length) {
    if (done.isNotEmpty || skipped.isNotEmpty) closeCycle();
    r++;
  }

  SessionId? next;
  for (final s in program.sessions) {
    if (!done.contains(s.id) && !skipped.contains(s.id)) {
      next = s.id;
      break;
    }
  }
  return ChainState(round: completed + 1, done: done, skipped: skipped, next: next);
}
