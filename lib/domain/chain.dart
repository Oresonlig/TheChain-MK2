/// Kedjan och cyklerna, härledda ur historiken (Gör om #9, beslut 6).
/// Passordningen är ett FÖRSLAG: vilket pass som helst kan köras, "nästa" är
/// första ej avklarade passet i programordning, och cykeln är klar när alla
/// pass (vilodagar inräknade) är gjorda — oavsett ordning (beslut 2026-10-02).
library;

import 'history.dart';
import 'ids.dart';
import 'program.dart';

class ChainState {
  const ChainState({required this.round, required this.done, required this.next});

  /// Pågående cykel, 1-baserad ("Round 18").
  final int round;

  /// Avklarade pass i pågående cykel.
  final Set<SessionId> done;

  /// Föreslaget nästa pass; null om programmet är tomt.
  final SessionId? next;

  bool isDone(SessionId id) => done.contains(id);
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
  var r = 0;

  void closeCycle() {
    completed++;
    done = <SessionId>{};
  }

  for (final e in entries) {
    // Omstarter före den här posten stänger pågående cykel (om den har innehåll).
    while (r < restarts.length && !restarts[r].isAfter(e.date)) {
      if (done.isNotEmpty) closeCycle();
      r++;
    }
    final id = switch (e) {
      WorkoutEntry(:final workout) => workout.sessionId,
      RestEntry(:final sessionId) => sessionId,
    };
    if (!all.contains(id)) continue;
    done.add(id);
    if (all.isNotEmpty && done.length == all.length) closeCycle();
  }
  while (r < restarts.length) {
    if (done.isNotEmpty) closeCycle();
    r++;
  }

  SessionId? next;
  for (final s in program.sessions) {
    if (!done.contains(s.id)) {
      next = s.id;
      break;
    }
  }
  return ChainState(round: completed + 1, done: done, next: next);
}
