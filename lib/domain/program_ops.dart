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

/// Permanent byte: platsen får en ny övning. Inget minne av den gamla.
Program swapPermanently(Program p, SessionId sessionId, SlotId slotId, ExerciseId to) =>
    _mapSession(p, sessionId, (s) {
      if (!s.slots.any((x) => x.id == slotId)) throw WorkoutError('No slot ${slotId.value}');
      return _withSlots(s, [for (final x in s.slots) x.id == slotId ? Slot(id: x.id, exerciseId: to) : x]);
    });

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

Program renameSession(Program p, SessionId id, String name) {
  final n = name.trim();
  if (n.isEmpty) throw const WorkoutError('Give the session a name');
  return _mapSession(p, id, (s) => Session(id: s.id, name: n, kind: s.kind, slots: s.slots));
}

Program addSession(Program p, Session s, {int? at}) {
  if (p.sessionById(s.id) != null) throw WorkoutError('Session ${s.id.value} exists');
  if (!s.isRest && s.name.trim().isEmpty) throw const WorkoutError('Give the session a name');
  final list = [...p.sessions];
  list.insert((at ?? list.length).clamp(0, list.length), s);
  return Program(sessions: list);
}

/// Historiken rörs inte: loggade pass bär sitt eget namn (Workout.sessionName).
/// Kedjan behöver minst ett träningspass.
Program removeSession(Program p, SessionId id) {
  final s = p.sessionById(id);
  if (s == null) throw WorkoutError('No session ${id.value}');
  if (!s.isRest && p.sessions.where((x) => !x.isRest).length == 1) {
    throw const WorkoutError('The chain needs at least one training session');
  }
  return Program(sessions: p.sessions.where((x) => x.id != id).toList());
}

/// Flyttar ett pass i kedjan (ändrar bara förslagsordningen).
Program moveSession(Program p, SessionId id, int toIndex) {
  final from = p.sessions.indexWhere((s) => s.id == id);
  if (from < 0) throw WorkoutError('No session ${id.value}');
  final list = [...p.sessions]..removeAt(from);
  list.insert(toIndex.clamp(0, list.length), p.sessions[from]);
  return Program(sessions: list);
}
