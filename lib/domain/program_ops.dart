/// Ändringar av programmet. Muterar EN struktur (Gör om #1) — inga parallella
/// kartor för tillagt/borttaget/ordning/byten som i MK1.
library;

import 'ids.dart';
import 'program.dart';
import 'workout_ops.dart' show WorkoutError;

Program _mapSession(Program p, SessionId id, Session Function(Session) f) {
  if (p.sessionById(id) == null) throw WorkoutError('No session ${id.value}');
  return Program(sessions: [for (final s in p.sessions) s.id == id ? f(s) : s]);
}

Session _withSlots(Session s, List<Slot> slots) =>
    Session(id: s.id, name: s.name, kind: s.kind, slots: slots);

/// Permanent byte. Originalet sparas första gången så att bytet kan ångras,
/// även efter flera byten i rad. Byte tillbaka till originalet nollställer.
Program swapPermanently(Program p, SessionId sessionId, SlotId slotId, ExerciseId to) =>
    _mapSession(p, sessionId, (s) {
      if (!s.slots.any((x) => x.id == slotId)) throw WorkoutError('No slot ${slotId.value}');
      return _withSlots(s, [
        for (final x in s.slots)
          if (x.id != slotId)
            x
          else
            (() {
              final original = x.originalExerciseId ?? x.exerciseId;
              return Slot(id: x.id, exerciseId: to, originalExerciseId: to == original ? null : original);
            })(),
      ]);
    });

/// Ångrar ett permanent byte.
Program revertSwap(Program p, SessionId sessionId, SlotId slotId) => _mapSession(p, sessionId, (s) => _withSlots(s, [
      for (final x in s.slots)
        x.id == slotId && x.originalExerciseId != null ? Slot(id: x.id, exerciseId: x.originalExerciseId!) : x,
    ]));

Program addSlot(Program p, SessionId sessionId, Slot slot) => _mapSession(p, sessionId, (s) {
      if (s.isRest) throw const WorkoutError('Rest days have no exercises');
      return _withSlots(s, [...s.slots, slot]);
    });

Program removeSlot(Program p, SessionId sessionId, SlotId slotId) =>
    _mapSession(p, sessionId, (s) => _withSlots(s, s.slots.where((x) => x.id != slotId).toList()));

/// Flyttar en plats till [toIndex] inom passet.
Program moveSlot(Program p, SessionId sessionId, SlotId slotId, int toIndex) => _mapSession(p, sessionId, (s) {
      final from = s.slots.indexWhere((x) => x.id == slotId);
      if (from < 0) throw WorkoutError('No slot ${slotId.value}');
      final list = [...s.slots]..removeAt(from);
      list.insert(toIndex.clamp(0, list.length), s.slots[from]);
      return _withSlots(s, list);
    });

Program renameSession(Program p, SessionId id, String name) =>
    _mapSession(p, id, (s) => Session(id: s.id, name: name.trim(), kind: s.kind, slots: s.slots));

Program addSession(Program p, Session s, {int? at}) {
  if (p.sessionById(s.id) != null) throw WorkoutError('Session ${s.id.value} exists');
  final list = [...p.sessions];
  list.insert((at ?? list.length).clamp(0, list.length), s);
  return Program(sessions: list);
}

Program removeSession(Program p, SessionId id) {
  if (p.sessionById(id) == null) throw WorkoutError('No session ${id.value}');
  return Program(sessions: p.sessions.where((s) => s.id != id).toList());
}

/// Flyttar ett pass i kedjan (ändrar bara förslagsordningen).
Program moveSession(Program p, SessionId id, int toIndex) {
  final from = p.sessions.indexWhere((s) => s.id == id);
  if (from < 0) throw WorkoutError('No session ${id.value}');
  final list = [...p.sessions]..removeAt(from);
  list.insert(toIndex.clamp(0, list.length), p.sessions[from]);
  return Program(sessions: list);
}
