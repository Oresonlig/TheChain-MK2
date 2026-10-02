/// Historiken: en lista av poster, en källa för PR, "förra gången" och
/// cykelräknaren (Gör om #7, #9, beslut 6). Vilodagar och importerad historik
/// är vanliga poster (Gör om #8, beslut 4–5).
library;

import 'ids.dart';
import 'workout.dart';

enum EntrySource {
  /// Loggat i appen.
  app,

  /// Inläst via appens egen importmall. Räknas som allt annat i PR-motorn.
  imported,
}

sealed class HistoryEntry {
  const HistoryEntry({required this.date, this.source = EntrySource.app});

  final DateTime date;
  final EntrySource source;
}

/// Ett avslutat träningspass.
class WorkoutEntry extends HistoryEntry {
  WorkoutEntry({required this.workout, super.source})
      : super(date: workout.startedAt);

  final Workout workout;
}

/// En avklarad vilodag. Räknas inte i PR eller passantal.
class RestEntry extends HistoryEntry {
  const RestEntry({required super.date, required this.sessionId, this.note});

  final SessionId sessionId;

  /// Valfri anteckning (beslut 5).
  final String? note;
}
