/// Kedjan och cyklerna, härledda ur historiken (Gör om #9, beslut 6).
/// Passordningen är ett FÖRSLAG: vilket pass som helst kan köras, "nästa" är
/// första ej avklarade passet i programordning, och cykeln är klar när alla
/// pass (vilodagar inräknade) är gjorda — oavsett ordning (beslut 2026-10-02).
/// Ett överhoppat pass (med anledning, 2026-10-04) räknas som hanterat.
library;

import 'history.dart';
import 'ids.dart';
import 'program.dart';
import 'set_entry.dart';

/// Den senast avslutade rundan — för "ROUND 18 COMPLETE" (Niklas 2026-10-05).
class RoundSummary {
  const RoundSummary({
    required this.round,
    required this.start,
    required this.end,
    required this.trained,
    required this.skipped,
    this.restDays = 0,
    this.sets = 0,
    this.skippedIds = const {},
    this.marks = const {},
  });

  /// Vilka pass som hoppades över — kryssas i fönstret (Niklas 2026-10-06).
  final Set<SessionId> skippedIds;

  /// Frö för temats ärr/klösmärke per pass — se [ChainState.marks].
  final Map<SessionId, int> marks;
  final int round;
  final DateTime start, end;

  /// Genomförda pass (vilodagar inräknade) och överhoppade i rundan.
  final int trained, skipped;

  /// Vilodagar bland [trained], och loggade arbetsset i rundans pass —
  /// summeringen i fönstret (Niklas 2026-10-06: "som ett litet pris").
  final int restDays, sets;

  int get sessions => trained - restDays;
}

class ChainState {
  const ChainState({
    required this.round,
    required this.done,
    required this.next,
    this.skipped = const {},
    this.lastRound,
    this.marks = const {},
  });

  /// Frö per hanterat pass = tiden för posten som gjorde det klart/överhoppat.
  /// Temats ärr och klösmärken väljer variant ur det (Niklas 2026-10-09): nytt
  /// utseende per runda, men samma pass ser likadant ut efter omstart.
  final Map<SessionId, int> marks;

  /// Senast avslutade rundan (null = ingen avslutad, eller avslutad av en omstart).
  final RoundSummary? lastRound;

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
  final rests = {for (final s in program.sessions) if (s.isRest) s.id};
  final restarts = manualRestarts.toList()..sort();
  final entries = history.where((e) => e.source == EntrySource.app).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  var completed = roundOffset;
  var done = <SessionId>{};
  var skipped = <SessionId>{};
  var marks = <SessionId, int>{};
  var r = 0;
  var sets = 0;
  DateTime? start;
  RoundSummary? last;

  void closeCycle({DateTime? end}) {
    completed++;
    // Bara en runda som fullbordades (inte en omstart) räknas som "klar".
    last = end == null || start == null
        ? null
        : RoundSummary(
            round: completed,
            start: start!,
            end: end,
            trained: done.length,
            skipped: skipped.length,
            restDays: done.where(rests.contains).length,
            sets: sets,
            skippedIds: Set.unmodifiable(skipped),
            marks: Map.unmodifiable(marks),
          );
    done = <SessionId>{};
    skipped = <SessionId>{};
    marks = <SessionId, int>{};
    sets = 0;
    start = null;
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
    start ??= e.date;
    if (e is WorkoutEntry) {
      for (final x in e.workout.exercises) {
        sets += x.sets.where((s) => s.isLogged && s.kind == SetKind.work).length;
      }
    }
    if (isSkip) {
      if (!done.contains(id)) {
        skipped.add(id);
        marks[id] = e.date.millisecondsSinceEpoch;
      }
    } else {
      skipped.remove(id);
      if (done.add(id)) marks[id] = e.date.millisecondsSinceEpoch;
    }
    if (all.isNotEmpty && done.length + skipped.length == all.length) closeCycle(end: e.date);
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
  return ChainState(round: completed + 1, done: done, skipped: skipped, next: next, lastRound: last, marks: marks);
}
