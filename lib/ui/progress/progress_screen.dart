/// Progress-fliken: PR per muskelgrupp + passhistoriken (med COPY). Grafer
/// och detaljvy per övning kommer i F4.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import '../copy_text.dart';
import '../format.dart';
import '../nanosuit_scaffold.dart';
import '../units.dart';
import 'exercise_detail_screen.dart';
import '../workout/exercise_picker.dart' show GroupHeader, groupLabel;

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.app});
  final AppController app;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _history = false;

  /// Öppna muskelgrupper i RECORDS — kollapsade som standard (Niklas 2026-10-03).
  final _openGroups = <MuscleGroup>{};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final repo = widget.app.repo;
        if (repo == null) return const SizedBox.shrink();
        final c = context.chain;
        final text = Theme.of(context).textTheme;
        final s = repo.settings();
        final history = repo.history();

        Widget toggle(String label, bool on) => Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _history = label == 'HISTORY'),
                child: SizedBox(
                  height: 48,
                  child: on
                      ? Raised(material: c.raisedActive, padding: EdgeInsets.zero, child: Center(child: Text(label, style: text.labelLarge)))
                      : Center(child: Text(label, style: text.labelLarge!.copyWith(color: c.textMuted))),
                ),
              ),
            );

        return ChainScaffold(
          ambient: s.ambientEffects,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text('PROGRESS', style: text.titleLarge!.copyWith(letterSpacing: 4)),
              const SizedBox(height: 16),
              Row(children: [toggle('RECORDS', !_history), const SizedBox(width: 8), toggle('HISTORY', _history)]),
              const SizedBox(height: 16),
              if (!_history) ..._records(repo.exercise, history, repo.hiddenRecords(), s, c, text) else ..._historyList(history, s, c, text),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _records(Exercise? Function(ExerciseId) exerciseOf, List<HistoryEntry> history, Set<ExerciseId> hidden,
      UserSettings s, ChainTheme c, TextTheme text) {
    final prs = personalRecords(history, hidden: hidden).values.toList();
    if (prs.isEmpty) return [Glass(child: Text('No records yet', style: text.bodySmall))];
    final byGroup = <MuscleGroup, List<PersonalRecord>>{};
    for (final pr in prs) {
      byGroup.putIfAbsent(exerciseOf(pr.exerciseId)?.group ?? MuscleGroup.other, () => []).add(pr);
    }
    final groups = byGroup.keys.toList()..sort((a, b) => groupLabel(a).compareTo(groupLabel(b)));
    return [
      for (final g in groups) ...[
        Glass(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GroupHeader(
              groupLabel(g),
              count: byGroup[g]!.length,
              open: _openGroups.contains(g),
              padding: 0,
              onTap: () => setState(() => _openGroups.contains(g) ? _openGroups.remove(g) : _openGroups.add(g)),
            ),
            if (_openGroups.contains(g)) ...[
              for (final pr in byGroup[g]!..sort((a, b) => (exerciseOf(a.exerciseId)?.name ?? '').compareTo(exerciseOf(b.exerciseId)?.name ?? '')))
                InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ExerciseDetailScreen(app: widget.app, exerciseId: pr.exerciseId),
                )),
                child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(exerciseOf(pr.exerciseId)?.name ?? pr.exerciseId.value, style: text.titleMedium),
                      Text(fmtDate(pr.date), style: text.bodySmall),
                    ]),
                  ),
                  Text(fmtRecord(pr, s.weightUnit), style: text.titleMedium!.copyWith(color: c.accentBright)),
                  Icon(Icons.chevron_right, color: c.textFaint, size: 20),
                ]),
              ),
                ),
              const SizedBox(height: 8),
            ],
          ]),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  List<Widget> _historyList(List<HistoryEntry> history, UserSettings s, ChainTheme c, TextTheme text) {
    final entries = [...history]..sort((a, b) => b.date.compareTo(a.date));
    if (entries.isEmpty) return [Glass(child: Text('No history yet', style: text.bodySmall))];
    final program = widget.app.repo!.program();
    String name(SessionId id) => program.sessionById(id)?.name ?? id.value;
    return [
      for (final e in entries.take(60))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Glass(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: switch (e) {
              RestEntry(:final sessionId, :final note) => Row(children: [
                  Text('V', style: text.titleMedium!.copyWith(color: c.restGold)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Forced rest day', style: text.titleMedium),
                      Text('${fmtDate(e.date)}${note == null ? '' : ' · $note'}', style: text.bodySmall),
                    ]),
                  ),
                  Text(sessionId.value, style: text.labelSmall),
                ]),
              SkippedEntry(:final sessionId, :final reason) => Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${name(sessionId)} — skipped', style: text.titleMedium!.copyWith(color: c.textMuted)),
                      Text('${fmtDate(e.date)} · $reason', style: text.bodySmall),
                    ]),
                  ),
                ]),
              WorkoutEntry(:final workout) => Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name(workout.sessionId), style: text.titleMedium),
                      Text(
                        '${fmtDate(e.date)} · ${workout.exercises.where((x) => x.status == ExerciseStatus.done).length} exercises'
                        '${e.source == EntrySource.imported ? ' · imported' : ''}',
                        style: text.bodySmall,
                      ),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Show',
                    onPressed: () => _showWorkout(context, workout, name(workout.sessionId), s),
                    icon: Icon(Icons.list_alt, color: c.textMuted),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: () => _copy(context, workout, name(workout.sessionId), s),
                    icon: Icon(Icons.copy, color: c.accent),
                  ),
                ]),
            },
          ),
        ),
    ];
  }

  Future<void> _copy(BuildContext context, Workout w, String sessionName, UserSettings s) async {
    final repo = widget.app.repo!;
    await Clipboard.setData(ClipboardData(
      text: buildCopyText(workout: w, sessionName: sessionName, nameOf: (id) => repo.exercise(id)?.name ?? id.value, settings: s),
    ));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  Future<void> _showWorkout(BuildContext context, Workout w, String sessionName, UserSettings s) {
    final repo = widget.app.repo!;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final text = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(shrinkWrap: true, children: [
              Text(sessionName.toUpperCase(), style: text.titleMedium),
              Text(fmtDate(w.finishedAt ?? w.startedAt), style: text.bodySmall),
              const SizedBox(height: 8),
              for (final ex in w.exercises.where((x) => x.status == ExerciseStatus.done)) ...[
                const SizedBox(height: 8),
                Text(repo.exercise(ex.exerciseId)?.name ?? ex.exerciseId.value, style: text.titleSmall),
                for (final set in ex.sets.where((x) => x.isLogged))
                  Text('${set.kind == SetKind.warmup ? 'W' : 'S'}  ${fmtSet(set, ex.measure, s)}', style: text.bodySmall),
              ],
            ]),
          ),
        );
      },
    );
  }
}
