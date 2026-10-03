/// En övnings utveckling: graf (ett set per pass — det bästa — alla pass, PR
/// markerade, "bästa hittills" som trappsteg) + passen i listform. Niklas
/// 2026-10-03: se "här gjorde jag PR, sen lyfte jag hälften i två månader".
library;

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import '../charts/chain_chart.dart';
import '../charts/chart_data.dart';
import '../charts/series.dart';
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

  @override
  Widget build(BuildContext context) {
    final repo = widget.app.repo!;
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final s = repo.settings();
    final history = repo.history();
    final ex = repo.exercise(widget.exerciseId);
    final name = ex?.name ?? widget.exerciseId.value;
    final prog = progression(history, widget.exerciseId);
    final measure = ex?.measure ?? (prog.isEmpty ? Measure.weight : prog.last.measure);
    final record = personalRecords(history)[widget.exerciseId];
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
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
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
                if (rows.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Nothing in this period', style: text.bodySmall)),
                for (final p in rows)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                    child: Row(children: [
                      SizedBox(width: 104, child: Text(fmtDate(p.date), style: text.bodySmall)),
                      Expanded(child: Text(fmtSet(p.set, p.measure, s), style: text.titleMedium)),
                      if (p.isPr) Text('PR', style: text.labelSmall!.copyWith(color: c.accentBright)),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
