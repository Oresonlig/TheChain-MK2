/// Programmet som EN struktur (Gör om #1). Ersätter MK1:s åtta kartor:
/// sessionOrder, restSlots, exerciseOverrides, permanentSwaps, addedExercises,
/// removedExercises, hiddenRemoved, exerciseOrder.
library;

import 'ids.dart';

enum SessionKind { training, rest }

/// En plats i ett pass. Ett permanent byte ändrar bara [exerciseId] — appen
/// minns inte originalet; vill man tillbaka byter man igen (Niklas 2026-10-04:
/// "jag kanske inte ens VILL tillbaka till originalövningen").
class Slot {
  const Slot({required this.id, required this.exerciseId});

  final SlotId id;
  final ExerciseId exerciseId;
}

class Session {
  const Session({
    required this.id,
    required this.name,
    this.kind = SessionKind.training,
    this.slots = const [],
  });

  final SessionId id;

  /// Användarens namn på passet. Vilodagar visas alltid som "V" i UI:t.
  final String name;
  final SessionKind kind;

  /// Ordnade platser. Tom för vilodagar.
  final List<Slot> slots;

  bool get isRest => kind == SessionKind.rest;
}

/// Passen i kedjans ordning. Ordningen är ett FÖRSLAG: vilket pass som helst
/// kan startas, och en cykel är klar när alla pass är gjorda (beslut 2026-10-02).
class Program {
  const Program({required this.sessions});

  final List<Session> sessions;

  Session? sessionById(SessionId id) {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }
}
