/// En övnings utveckling: graf (ett set per pass — det bästa — alla pass, PR
/// markerade, "bästa hittills" som trappsteg) + passen i listform. Niklas
/// 2026-10-03: se "här gjorde jag PR, sen lyfte jag hälften i två månader".
library;

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/background_scope.dart';
import '../../theme/surfaces.dart';
import '../charts/chain_chart.dart';
import '../charts/chart_data.dart';
import '../charts/series.dart';
import '../delete_ux.dart';
import '../format.dart';
import '../nanosuit_scaffold.dart';
import '../units.dart';

class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key, required this.app, required this.exerciseId});

  final AppController app;
  final ExerciseId exerciseId;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> with ChartRangeState {
  @override
  String get rangeKey => 'pr';

  @override
  void initState() {
    super.initState();
    loadSavedRange();
  }

  // Läser om när synken hämtat något (annan enhet) — inte bara vid öppning.
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final repo = widget.app.repo;
    if (repo == null) return const SizedBox.shrink(); // utloggad; vyn stängs
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final s = repo.settings();
    final history = repo.history();
    final ex = repo.exercise(widget.exerciseId);
    final name = ex?.name ?? widget.exerciseId.value;
    // Bara pass loggade med övningens nuvarande mätsätt — som RECORDS.
    final prog = progression(history, widget.exerciseId, measure: ex?.measure);
    final measure = ex?.measure ?? (prog.isEmpty ? Measure.weight : prog.last.measure);
    final record = repo.records()[widget.exerciseId];
    final win = window(DateTime.now());
    final series = prSeries(prog, measure, win, s, (p) => fmtSet(p.set, p.measure, s));
    final rows = inWindow(prog, (p) => p.date, win).reversed.toList();

    return ChainScaffold(
      ambient: s.ambientEffects,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
          child: Row(children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, color: c.textMuted),
            ),
            Expanded(child: Text(name, style: text.titleLarge, overflow: TextOverflow.ellipsis)),
          ]),
        ),
        Expanded(
          child: ListView(addRepaintBoundaries: glassListRepaintBoundaries, padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            Glass(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(measureDescription(measure).toUpperCase(), style: text.labelSmall)),
                  if (record != null)
                    Text('PR ${fmtRecord(record, s.weightUnit)}', style: text.labelSmall!.copyWith(color: c.accentBright)),
                ]),
                if (record != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(fmtDate(record.date), style: text.labelSmall),
                  ),
                if (range == ChartRange.custom)
                  Text(win.label, style: text.labelSmall!.copyWith(color: c.textStrong)),
                const SizedBox(height: 6),
                RangeChips(value: range, onChanged: selectRange),
                const SizedBox(height: 4),
                ChainChart(series: series, height: 240, animate: s.ambientEffects),
              ]),
            ),
            const SizedBox(height: 12),
            Glass(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('SESSIONS · BEST SET', style: text.labelSmall),
                // Nybörjartestet (Niklas 2026-10-06): raderna ser statiska ut.
                if (rows.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2, bottom: 4), child: Text('Tap a set to delete it.', style: text.bodySmall)),
                if (rows.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Nothing in this period', style: text.bodySmall)),
                for (final p in rows)
                  // Tryck = radera felloggat set (Niklas 2026-10-06).
                  InkWell(
                    onTap: () => _deleteSet(context, p, record, ex?.measure, name),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                      child: Row(children: [
                        SizedBox(width: 104, child: Text(fmtDate(p.date), style: text.bodySmall)),
                        Expanded(child: Text(fmtSet(p.set, p.measure, s), style: text.titleMedium)),
                        if (p.isPr) Text('PR', style: text.labelSmall!.copyWith(color: c.accentBright)),
                      ]),
                    ),
                  ),
              ]),
            ),
            if (history.whereType<WorkoutEntry>().any((e) => withoutExercise(e, widget.exerciseId) != null))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: () => _deleteAll(context, name),
                  child: Text('Delete all history', style: TextStyle(color: c.textMuted)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  /// Ett felloggat set bort. Bekräftelsen säger vad PR blir efteråt.
  Future<void> _deleteSet(BuildContext context, ProgressionPoint p, PersonalRecord? record, Measure? measure, String name) async {
    final s = widget.app.repo!.settings();
    final next = withoutSet(p.entry, p.rowId, p.set.id);
    if (next == null) return;
    final setLabel = '${fmtSet(p.set, p.measure, s)} · ${fmtDate(p.date)}';
    String prLine;
    if (record != null && record.set.id == p.set.id && record.date == p.date) {
      final history = [
        for (final h in widget.app.repo!.history())
          if (h is WorkoutEntry && h.workout.id == p.entry.workout.id) next else h,
      ];
      final after = personalRecords(history, measureOf: (_) => measure)[widget.exerciseId];
      prLine = after == null ? 'You will have no PR for $name.' : 'Your PR becomes ${fmtRecord(after, s.weightUnit)}.';
    } else {
      prLine = record == null ? '' : 'Your PR stays ${fmtRecord(record, s.weightUnit)}.';
    }
    final ok = await confirmDelete(
      context,
      title: 'Delete this set?',
      body: '$setLabel\n\nIt is removed from history on all your devices. The session stays in the chain. $prLine'.trim(),
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await widget.app.deleteLoggedSet(p.entry, p.rowId, p.set.id);
    showUndo(messenger, 'Deleted $setLabel', () => widget.app.restoreHistoryEntry(p.entry));
  }

  /// Hela övningens historik bort (t.ex. loggad på fel övning). Passen står kvar.
  Future<void> _deleteAll(BuildContext context, String name) async {
    final affected = [
      for (final e in widget.app.repo!.history().whereType<WorkoutEntry>())
        if (withoutExercise(e, widget.exerciseId) != null) e,
    ];
    final sets = affected
        .expand((e) => e.workout.exercises)
        .where((x) => x.exerciseId == widget.exerciseId)
        .fold<int>(0, (n, x) => n + x.sets.where((st) => st.isLogged).length);
    final ok = await confirmDelete(
      context,
      title: 'Delete all history for $name?',
      body: '${affected.length} ${affected.length == 1 ? 'session' : 'sessions'} · $sets ${sets == 1 ? 'set' : 'sets'}. '
          'Records, graph and "Last" start over. The sessions stay in the chain.',
      action: 'Delete all',
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final before = await widget.app.deleteExerciseHistory(widget.exerciseId);
    showUndo(messenger, 'Deleted all history for $name', () => widget.app.restoreHistoryEntries(before));
  }
}
