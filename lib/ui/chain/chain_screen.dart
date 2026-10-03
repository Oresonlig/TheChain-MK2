/// F3 — kedjevyn (hem). Slidern överst; under den det valda passet med
/// övningar och "förra gången", och knappen för att starta/fortsätta.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import '../copy_text.dart';
import '../dev_home_screen.dart';
import '../nanosuit_scaffold.dart';
import '../units.dart';
import '../workout/workout_screen.dart';
import 'chain_strip.dart';

class ChainScreen extends StatefulWidget {
  const ChainScreen({super.key, required this.app, this.email = '', this.buildLabel = '', this.now});

  final AppController app;
  final String email;
  final String buildLabel;
  final DateTime Function()? now;

  @override
  State<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends State<ChainScreen> {
  SessionId? _selected;

  DateTime get _now => (widget.now ?? DateTime.now)();

  Future<void> _openWorkout(SessionId id) async {
    final wc = widget.app.openWorkout(id);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WorkoutScreen(controller: wc)));
    if (mounted) setState(() => _selected = null); // tillbaka: visa nästa föreslagna
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) => ChainScaffold(
        ambient: widget.app.repo?.settings().ambientEffects ?? true,
        child: _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return Builder(
      builder: (context) => ListenableBuilder(
        listenable: widget.app,
        builder: (context, _) {
          final repo = widget.app.repo;
          if (repo == null) return const Center(child: CircularProgressIndicator());
          final c = context.chain;
          final text = Theme.of(context).textTheme;
          final program = repo.program();
          final chain = repo.chain();
          final history = repo.history();
          final inProgress = {for (final w in repo.activeWorkouts()) w.sessionId};

          if (program.sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Glass(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('No program yet', style: text.titleLarge),
                  const SizedBox(height: 8),
                  Text('Import your data from the website to get started.', style: text.bodySmall, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextButton(onPressed: () => _openDev(context), child: const Text('OPEN DATA CHECK')),
                  ]),
                ),
              ),
            );
          }

          final selected = _selected ?? inProgress.firstOrNull ?? chain.next ?? program.sessions.first.id;
          final session = program.sessionById(selected) ?? program.sessions.first;
          final trainingCount = program.sessions.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('THE', style: text.titleLarge!.copyWith(letterSpacing: 5, fontSize: 22)),
                    Text('CHAIN',
                        style: text.titleLarge!.copyWith(
                          letterSpacing: 5,
                          fontSize: 22,
                          color: c.accent,
                          shadows: [Shadow(color: c.accent.withValues(alpha: .6), blurRadius: 12)],
                        )),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(widget.buildLabel, style: text.labelSmall),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(widget.app.status == 'Synced' ? 'SYNCED' : 'SYNC', style: text.labelSmall),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.app.status == 'Synced' ? c.success : c.textFaint,
                      ),
                    ),
                  ]),
                ]),
              ]),
              if (widget.app.update != null) ...[
                const SizedBox(height: 8),
                _UpdateBanner(app: widget.app),
              ],
              const SizedBox(height: 8),
              Text('${chain.done.length}/$trainingCount sessions done · Round ${chain.round}', style: text.bodySmall),
              const SizedBox(height: 10),
              ChainStrip(
                program: program,
                chain: chain,
                selected: session.id,
                inProgress: inProgress,
                onSelect: (id) => setState(() => _selected = id),
              ),
              const SizedBox(height: 20),
              if (session.isRest)
                _RestPanel(
                  key: ValueKey('rest-${session.id.value}'),
                  done: chain.isDone(session.id),
                  onDone: (note) => widget.app.markRestDone(session.id, note: note),
                  onUndo: () async {
                    final last = (history.whereType<RestEntry>().where((e) => e.sessionId == session.id).toList()
                          ..sort((a, b) => b.date.compareTo(a.date)))
                        .firstOrNull;
                    if (last != null && await _confirmUndo(context, rest: true)) await widget.app.undoRest(last);
                  },
                )
              else
                _SessionPanel(
                  session: session,
                  letter: ChainStrip.letters(program)[session.id]!,
                  isNext: chain.next == session.id,
                  done: chain.isDone(session.id),
                  inProgress: inProgress.contains(session.id),
                  history: history,
                  now: _now,
                  exerciseOf: (id) => repo.exercise(id),
                  settings: repo.settings(),
                  onStart: () => _openWorkout(session.id),
                  onCopy: (entry) async {
                    await Clipboard.setData(ClipboardData(
                      text: buildCopyText(
                        workout: entry.workout,
                        sessionName: session.name,
                        nameOf: (id) => repo.exercise(id)?.name ?? id.value,
                        settings: repo.settings(),
                      ),
                    ));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                    }
                  },
                  onUndo: (entry) async {
                    if (await _confirmUndo(context)) await widget.app.undoWorkout(entry);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _confirmUndo(BuildContext context, {bool rest = false}) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(rest ? 'Undo rest day?' : 'Undo this session?'),
          content: Text(rest
              ? 'The rest day is marked as not done again.'
              : 'The session opens again with everything you logged, so you can fix it. '
                  'It counts as done again when you finish it.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Undo')),
          ],
        ),
      ) ==
      true;

  void _openDev(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => DevHomeScreen(app: widget.app, email: widget.email, buildLabel: widget.buildLabel),
      ));
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final busy = app.updateStatus != null && app.updateStatus!.startsWith('Downloading');
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(children: [
        Icon(Icons.system_update, color: c.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Update available · build ${app.update!.build}', style: text.titleMedium),
            if (app.updateStatus != null) Text(app.updateStatus!, style: text.bodySmall),
          ]),
        ),
        GestureDetector(
          onTap: busy ? null : app.installUpdate,
          child: Raised(
            material: c.raisedActive,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(busy ? '…' : 'UPDATE', style: text.labelLarge!.copyWith(fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}

class _SessionPanel extends StatelessWidget {
  const _SessionPanel({
    required this.session,
    required this.letter,
    required this.isNext,
    required this.done,
    required this.inProgress,
    required this.history,
    required this.now,
    required this.exerciseOf,
    required this.settings,
    required this.onStart,
    required this.onCopy,
    required this.onUndo,
  });

  final Session session;
  final String letter;
  final bool isNext, done, inProgress;
  final List<HistoryEntry> history;
  final DateTime now;
  final Exercise? Function(ExerciseId) exerciseOf;
  final UserSettings settings;
  final VoidCallback onStart;
  final ValueChanged<WorkoutEntry> onCopy;
  final ValueChanged<WorkoutEntry> onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final lastOfSession = (history.whereType<WorkoutEntry>().where((e) => e.workout.sessionId == session.id).toList()
          ..sort((a, b) => b.date.compareTo(a.date)))
        .firstOrNull;
    final statusText = inProgress
        ? 'IN PROGRESS'
        : done
            ? 'DONE · ${daysAgo(lastOfSession?.date ?? now, now).toUpperCase()}'
            : isNext
                ? 'NEXT UP'
                : 'LATER IN THE CHAIN';
    final statusColor = inProgress ? c.success : (done ? c.textFaint : c.accent);

    return Glass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(letter, style: text.titleLarge!.copyWith(color: c.accent)),
          const SizedBox(width: 12),
          Expanded(child: Text(session.name.toUpperCase(), style: text.titleMedium!.copyWith(letterSpacing: 2))),
        ]),
        const SizedBox(height: 4),
        Text(statusText, style: text.labelSmall!.copyWith(color: statusColor)),
        const SizedBox(height: 12),
        // Avslutat pass är LÅST (Niklas 2026-10-02): visa vad som gjordes +
        // COPY och UNDO. Ingen "train again".
        if (done && !inProgress && lastOfSession != null) ...[
          for (final ex in lastOfSession.workout.exercises) _DoneExercise(
            name: exerciseOf(ex.exerciseId)?.name ?? ex.exerciseId.value,
            row: ex,
            settings: settings,
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: GhostButton(
                label: 'UNDO',
                leadingIcon: Icons.undo,
                onTap: () => onUndo(lastOfSession),
                color: c.textMuted,
                borderColor: c.borderStrong,
                height: 52,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => onCopy(lastOfSession),
                child: Raised(
                  material: c.raisedActive,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.copy, size: 18, color: c.textStrong),
                    const SizedBox(width: 8),
                    Text('COPY', style: text.labelLarge),
                  ]),
                ),
              ),
            ),
          ]),
        ] else ...[
          for (final slot in session.slots) _ExercisePreview(
            exercise: exerciseOf(slot.exerciseId),
            id: slot.exerciseId,
            last: lastPerformance(history, slot.exerciseId),
            now: now,
            settings: settings,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onStart,
            child: Raised(
              material: c.raisedActive,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text(inProgress ? 'CONTINUE SESSION' : 'START SESSION', style: text.labelLarge)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _DoneExercise extends StatelessWidget {
  const _DoneExercise({required this.name, required this.row, required this.settings});
  final String name;
  final WorkoutExercise row;
  final UserSettings settings;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final sets = row.sets.where((s) => s.isLogged).toList();
    var w = 0, s = 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: text.titleMedium!.copyWith(color: row.status == ExerciseStatus.skipped ? c.textFaint : c.textStrong)),
        if (row.status == ExerciseStatus.skipped)
          Text('Skipped', style: text.bodySmall)
        else
          for (final set in [...sets.where((x) => x.kind == SetKind.warmup), ...sets.where((x) => x.kind == SetKind.work)])
            Text(
              '${set.kind == SetKind.warmup ? 'W${++w}' : 'S${++s}'}  ${fmtSet(set, row.measure, settings)}',
              style: text.bodySmall!.copyWith(color: set.kind == SetKind.work ? c.textBody : c.textMuted),
            ),
      ]),
    );
  }
}

class _ExercisePreview extends StatelessWidget {
  const _ExercisePreview({required this.exercise, required this.id, required this.last, required this.now, required this.settings});

  final Exercise? exercise;
  final ExerciseId id;
  final LastPerformance? last;
  final DateTime now;
  final UserSettings settings;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final m = last?.exercise.measure ?? exercise?.measure ?? Measure.weight;
    final summary = last == null ? 'No history yet' : last!.workSets.map((s) => fmtSet(s, m, settings)).join('  ·  ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(exercise?.name ?? id.value, style: text.titleMedium),
        const SizedBox(height: 2),
        Text(
          last == null ? summary : 'Last (${daysAgo(last!.date, now)}): $summary',
          style: text.bodySmall,
        ),
      ]),
    );
  }
}

class _RestPanel extends StatefulWidget {
  const _RestPanel({super.key, required this.done, required this.onDone, required this.onUndo});

  final bool done;
  final Future<void> Function(String? note) onDone;
  final VoidCallback onUndo;

  @override
  State<_RestPanel> createState() => _RestPanelState();
}

class _RestPanelState extends State<_RestPanel> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return Glass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('V', style: text.titleLarge!.copyWith(color: c.restGold)),
          const SizedBox(width: 12),
          Text('REST DAY', style: text.titleMedium!.copyWith(letterSpacing: 2)),
        ]),
        const SizedBox(height: 4),
        Text(widget.done ? 'DONE' : 'Active rest — a light walk or stretching.',
            style: text.labelSmall!.copyWith(color: widget.done ? c.textFaint : c.restGold)),
        if (widget.done) ...[
          const SizedBox(height: 16),
          GhostButton(
            label: 'UNDO',
            leadingIcon: Icons.undo,
            onTap: widget.onUndo,
            color: c.textMuted,
            borderColor: c.borderStrong,
            height: 52,
          ),
        ],
        if (!widget.done) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            style: text.bodyMedium!.copyWith(color: c.textStrong),
            decoration: InputDecoration(
              hintText: 'Note (optional)',
              hintStyle: text.bodySmall,
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.borderStrong), borderRadius: BorderRadius.zero),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: c.restGold), borderRadius: BorderRadius.zero),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => widget.onDone(_note.text),
            child: Raised(
              material: c.raisedActive,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('MARK REST DAY DONE', style: text.labelLarge)),
            ),
          ),
        ],
      ]),
    );
  }
}
