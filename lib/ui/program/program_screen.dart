/// Programbyggaren (Niklas 2026-10-04): TVÅ skärmar — kedjan och passet —
/// plus väljaren och egenskapsbladet. Inget mer. Allt sparas direkt; det som
/// tas bort får UNDO i nederkant. Ett pågående pass är en ögonblicksbild och
/// påverkas inte av ändringar här.
library;

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import '../chain/chain_strip.dart';
import '../nanosuit_scaffold.dart';
import '../units.dart';
import '../workout/exercise_picker.dart';
import 'exercise_sheet.dart';

void _snack(BuildContext context, String message, {VoidCallback? undo}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: undo == null ? null : SnackBarAction(label: 'UNDO', onPressed: undo),
      // En snackbar med knapp ligger annars kvar tills den dras bort (Niklas
      // 2026-10-04: UNDO ska försvinna av sig själv efter några sekunder).
      persist: false,
      duration: const Duration(seconds: 5),
    ));
}

/// Kör en ändring; ett nekat försök visas som besked, inget sparas.
Future<Program?> _edit(BuildContext context, AppController app, Program Function(Program) op) async {
  try {
    return await app.editProgram(op);
  } on WorkoutError catch (e) {
    if (context.mounted) _snack(context, e.message);
    return null;
  }
}

Future<String?> _askName(BuildContext context, {required String title, String initial = ''}) {
  // Ingen dispose: dialogens stängningsanimation läser fältet efter pop.
  final field = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final ok = field.text.trim().isNotEmpty;
        void submit() => Navigator.pop(ctx, field.text.trim());
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: field,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setLocal(() {}),
            onSubmitted: (_) => ok ? submit() : null,
            decoration: const InputDecoration(hintText: 'e.g. Chest, Back, Legs'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: ok ? submit : null, child: const Text('Save')),
          ],
        );
      },
    ),
  );
}

/// Rubrikrad med tillbaka-pil, som övriga undersidor.
Widget _header(BuildContext context, String title, {Widget? trailing}) {
  final c = context.chain;
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
    child: Row(children: [
      IconButton(tooltip: 'Back', onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back, color: c.textMuted)),
      Expanded(
        child: Text(title,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(letterSpacing: 3), overflow: TextOverflow.ellipsis),
      ),
      ?trailing,
    ]),
  );
}

/// "B is in progress · changes apply next time" — så att ingen tror att
/// dagens pass ändrades.
Widget _inProgressNote(BuildContext context, String name) {
  final c = context.chain;
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Icon(Icons.info_outline, size: 16, color: c.success),
      const SizedBox(width: 8),
      Expanded(
        child: Text('$name is in progress · changes apply next time',
            style: Theme.of(context).textTheme.labelSmall!.copyWith(color: c.success)),
      ),
    ]),
  );
}

Widget _dragHandle(BuildContext context, int index) => ReorderableDragStartListener(
      index: index,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(Icons.drag_handle, color: context.chain.textMuted),
      ),
    );

Widget _proxy(Widget child, int index, Animation<double> animation) =>
    Material(type: MaterialType.transparency, child: child);

// ─────────────────────────────── kedjan ───────────────────────────────

class ProgramScreen extends StatelessWidget {
  const ProgramScreen({super.key, required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final repo = app.repo;
        return ChainScaffold(
          ambient: repo?.settings().ambientEffects ?? true,
          child: repo == null
              ? const SizedBox.shrink() // utloggad; vyn stängs
              : Column(children: [
                  _header(context, 'PROGRAM'),
                  Expanded(child: _list(context, repo.program(), repo.activeWorkouts())),
                ]),
        );
      },
    );
  }

  Widget _list(BuildContext context, Program program, List<Workout> active) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final letters = ChainStrip.letters(program);
    final activeName = active.isEmpty
        ? null
        : (active.first.sessionName ?? program.sessionById(active.first.sessionId)?.name ?? 'A session');

    return ReorderableListView(
      buildDefaultDragHandles: false,
      proxyDecorator: _proxy,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (activeName != null) _inProgressNote(context, activeName),
        if (program.sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Add your first session. Each one gets a letter — A, B, C — in the order you set here.',
                style: text.bodySmall),
          ),
      ]),
      footer: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(child: GhostButton(label: '+ SESSION', onTap: () => _addSession(context, program))),
          const SizedBox(width: 12),
          Expanded(child: GhostButton(label: '+ REST DAY', color: c.restGold, onTap: () => _addRest(context))),
        ]),
      ),
      onReorderItem: (from, to) {
        final id = program.sessions[from].id;
        _edit(context, app, (p) => moveSession(p, id, to));
      },
      children: [
        for (final (i, s) in program.sessions.indexed)
          Padding(
            key: ValueKey(s.id.value),
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: s.isRest ? null : () => _openSession(context, s.id),
              child: Glass(
                padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
                child: Row(children: [
                  _dragHandle(context, i),
                  SizedBox(
                    width: 28,
                    child: Text(letters[s.id]!, style: text.titleLarge!.copyWith(color: s.isRest ? c.restGold : c.accent)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.isRest ? 'Forced Rest Day' : s.name, style: text.titleMedium, overflow: TextOverflow.ellipsis),
                      if (!s.isRest)
                        Text(
                          switch (s.slots.length) {
                            0 => 'No exercises yet',
                            1 => '1 exercise',
                            final n => '$n exercises',
                          },
                          style: text.bodySmall!.copyWith(color: s.slots.isEmpty ? c.fail : null),
                        ),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'More',
                    onPressed: () => _menu(context, s),
                    icon: Icon(Icons.more_vert, color: c.textMuted),
                  ),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  void _openSession(BuildContext context, SessionId id) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SessionEditScreen(app: app, sessionId: id)));

  Future<void> _addSession(BuildContext context, Program program) async {
    final name = await _askName(context, title: 'New session');
    if (name == null || !context.mounted) return;
    final id = SessionId(app.newId());
    final before = await _edit(context, app, (p) => addSession(p, Session(id: id, name: name)));
    if (before != null && context.mounted) _openSession(context, id);
  }

  Future<void> _addRest(BuildContext context) =>
      _edit(context, app, (p) => addSession(p, Session(id: SessionId(app.newId()), name: 'Rest', kind: SessionKind.rest)));

  Future<void> _menu(BuildContext context, Session s) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!s.isRest)
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Rename'), onTap: () => Navigator.pop(ctx, 'rename')),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(s.isRest ? 'Remove forced rest day' : 'Remove session'),
            subtitle: s.isRest ? null : const Text('History and records are kept'),
            onTap: () => Navigator.pop(ctx, 'remove'),
          ),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'rename') {
      final name = await _askName(context, title: 'Rename session', initial: s.name);
      if (name != null && context.mounted) await _edit(context, app, (p) => renameSession(p, s.id, name));
      return;
    }
    try {
      final before = await app.deleteSession(s.id);
      if (context.mounted) {
        _snack(context, 'Removed ${s.isRest ? 'forced rest day' : s.name}', undo: () => app.restoreProgram(before));
      }
    } on WorkoutError catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }
}

// ─────────────────────────────── passet ───────────────────────────────

class SessionEditScreen extends StatelessWidget {
  const SessionEditScreen({super.key, required this.app, required this.sessionId});
  final AppController app;
  final SessionId sessionId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final repo = app.repo;
        final program = repo?.program();
        final session = program?.sessionById(sessionId);
        return ChainScaffold(
          ambient: repo?.settings().ambientEffects ?? true,
          // Utloggad, eller passet togs bort på en annan enhet.
          child: (repo == null || session == null)
              ? Column(children: [_header(context, '')])
              : Column(children: [
                  _header(
                    context,
                    '${ChainStrip.letters(program!)[session.id]} · ${session.name.toUpperCase()}',
                    trailing: IconButton(
                      tooltip: 'Rename',
                      onPressed: () => _rename(context, session),
                      icon: Icon(Icons.edit_outlined, color: context.chain.textMuted),
                    ),
                  ),
                  Expanded(child: _list(context, repo.exercise, session, repo.activeWorkoutFor(session.id) != null)),
                ]),
        );
      },
    );
  }

  Widget _list(BuildContext context, Exercise? Function(ExerciseId) exerciseOf, Session session, bool inProgress) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return ReorderableListView(
      buildDefaultDragHandles: false,
      proxyDecorator: _proxy,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (inProgress) _inProgressNote(context, session.name),
        if (session.slots.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('No exercises yet. Add them below — pick several at once.', style: text.bodySmall),
          ),
      ]),
      footer: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GhostButton(label: '+ ADD EXERCISES', onTap: () => _add(context, session)),
      ),
      onReorderItem: (from, to) {
        final id = session.slots[from].id;
        _edit(context, app, (p) => moveSlot(p, session.id, id, to));
      },
      children: [
        for (final (i, slot) in session.slots.indexed)
          Padding(
            key: ValueKey(slot.id.value),
            padding: const EdgeInsets.only(bottom: 8),
            child: Builder(builder: (context) {
              final ex = exerciseOf(slot.exerciseId);
              final details = [
                if (ex != null) measureDescription(ex.measure),
                if (ex?.scheme == SetScheme.ramp) 'ramp',
                if (ex?.scheme == SetScheme.singles) 'singles',
                if (ex?.unilateral ?? false) 'L/R',
              ].join(' · ');
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: ex == null ? null : () => showExerciseSheet(context, app: app, exercise: ex),
                child: Glass(
                  padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
                  child: Row(children: [
                    _dragHandle(context, i),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(ex?.name ?? slot.exerciseId.value, style: text.titleMedium),
                        if (details.isNotEmpty) Text(details, style: text.bodySmall),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Remove ${ex?.name ?? ''}',
                      onPressed: () => _remove(context, session, slot, ex?.name ?? slot.exerciseId.value),
                      icon: Icon(Icons.close, color: c.textMuted),
                    ),
                  ]),
                ),
              );
            }),
          ),
      ],
    );
  }

  Future<void> _rename(BuildContext context, Session session) async {
    final name = await _askName(context, title: 'Rename session', initial: session.name);
    if (name != null && context.mounted) await _edit(context, app, (p) => renameSession(p, session.id, name));
  }

  Future<void> _add(BuildContext context, Session session) async {
    final repo = app.repo!;
    final ids = await pickExercises(
      context,
      title: 'Add to ${session.name}',
      custom: repo.customExercises().values.toList(),
      recent: recentExercises(repo.history()),
      already: {for (final s in session.slots) s.exerciseId},
      onCreate: (ctx, name) => showExerciseSheet(ctx, app: app, newName: name),
    );
    if (ids.isEmpty || !context.mounted) return;
    await _edit(context, app, (p) {
      var out = p;
      for (final id in ids) {
        out = addSlot(out, session.id, Slot(id: SlotId(app.newId()), exerciseId: id));
      }
      return out;
    });
  }

  Future<void> _remove(BuildContext context, Session session, Slot slot, String name) async {
    final before = await _edit(context, app, (p) => removeSlot(p, session.id, slot.id));
    if (before != null && context.mounted) {
      _snack(context, 'Removed $name from ${session.name}', undo: () => app.restoreProgram(before));
    }
  }
}
