/// F3 — passvyn. En övning expanderad åt gången. Uppvärmning och arbetsset
/// har tydligt avstånd och stora träffytor (Niklas #3: "brottarfingrar").
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/workout_controller.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import '../nanosuit_scaffold.dart';
import '../units.dart';
import 'exercise_picker.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, required this.controller, this.now});

  final WorkoutController controller;
  final DateTime Function()? now;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  WorkoutController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_showError);
  }

  @override
  void dispose() {
    controller.removeListener(_showError);
    super.dispose();
  }

  /// Fel visas i nederkant så de syns oavsett var man har scrollat.
  void _showError() {
    final e = controller.takeError();
    if (e == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e)));
  }

  @override
  Widget build(BuildContext context) {
    return ChainScaffold(
      ambient: controller.repo.settings().ambientEffects,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = context.chain;
          final text = Theme.of(context).textTheme;
          final w = controller.workout;
          final session = controller.repo.program().sessionById(w.sessionId);
          final doneCount = w.exercises.where((e) => e.status != ExerciseStatus.open).length;
          final canFinish = controller.canFinish;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(children: [
                IconButton(
                  tooltip: 'Back to the chain',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, color: c.textMuted),
                ),
                Expanded(
                  child: Text((session?.name ?? w.sessionId.value).toUpperCase(),
                      style: text.titleMedium!.copyWith(letterSpacing: 2), overflow: TextOverflow.ellipsis),
                ),
                Text('$doneCount/${w.exercises.length}', style: text.labelSmall),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  for (final r in w.exercises) ...[
                    ExerciseCard(
                      key: ValueKey(r.id),
                      controller: controller,
                      row: r,
                      expanded: controller.expandedRowId == r.id,
                      now: (widget.now ?? DateTime.now)(),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Samma glas som korten: knapparna får aldrig drunkna i
                  // hex-vågen (Niklas 2026-10-03).
                  Glass(
                    padding: const EdgeInsets.all(10),
                    child: _SecondaryButton(
                      label: '+ ADD EXERCISE',
                      onTap: () async {
                        final id = await pickExercise(context,
                            title: 'Add exercise (today only)', custom: controller.repo.customExercises().values.toList());
                        if (id != null) controller.addExtra(id);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Glass(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      GestureDetector(
                        onTap: canFinish
                            ? () async {
                                final ok = await controller.finish();
                                if (ok && context.mounted) Navigator.pop(context);
                              }
                            : null,
                        // Släckt = dämpat material, inte genomskinligt (alpha är ett fönster).
                        child: Raised(
                          material: canFinish ? c.raisedActive : c.raisedIdle,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: Text('FINISH SESSION',
                                style: text.labelLarge!.copyWith(color: canFinish ? c.textStrong : c.textFaint)),
                          ),
                        ),
                      ),
                      if (!canFinish)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Mark every exercise done or skip it first', style: text.labelSmall, textAlign: TextAlign.center),
                        ),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: () => _confirmDiscard(context),
                          child: Text('Discard session', style: text.bodySmall),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this session?'),
        content: const Text('Everything logged in this session is removed on all your devices.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    if (ok == true) {
      await controller.discard();
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap, this.color, this.semanticLabel, this.icon});
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final String? semanticLabel;

  /// Ersätter texten (minus-tecknet är för litet i Saira).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final col = color ?? c.secondaryAction;
    return Semantics(
      label: semanticLabel,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: col,
          disabledForegroundColor: c.textFaint,
          side: BorderSide(color: onTap == null ? c.border : col.withValues(alpha: .5)),
          minimumSize: const Size(0, 48), // stora träffytor
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: const RoundedRectangleBorder(),
          textStyle: Theme.of(context).textTheme.labelSmall,
        ),
        child: icon == null ? Text(label) : Icon(icon, size: 22),
      ),
    );
  }
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({super.key, required this.controller, required this.row, required this.expanded, required this.now});

  final WorkoutController controller;
  final WorkoutExercise row;
  final bool expanded;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final ex = controller.exerciseOf(row);
    final settings = controller.repo.settings();
    final logged = row.sets.where((s) => s.isLogged).length;
    final statusText = switch (row.status) {
      ExerciseStatus.done => 'DONE',
      ExerciseStatus.skipped => 'SKIPPED',
      ExerciseStatus.open => logged == 0 ? '' : '$logged/${row.sets.length} LOGGED',
    };

    final header = InkWell(
      onTap: () => controller.expand(row.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(expanded ? Icons.expand_less : Icons.expand_more, color: c.textFaint, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ex.name,
                  style: (expanded ? text.titleLarge : text.titleMedium)!.copyWith(
                    color: row.status == ExerciseStatus.open ? c.textStrong : c.textMuted,
                  )),
              if (row.temporarySwapFrom != null)
                Text('Swapped for today', style: text.labelSmall!.copyWith(color: c.accent)),
              if (row.isExtra) Text('Extra · today only', style: text.labelSmall!.copyWith(color: c.accent)),
            ]),
          ),
          if (statusText.isNotEmpty)
            Text(statusText,
                style: text.labelSmall!.copyWith(color: row.status == ExerciseStatus.done ? c.success : c.textFaint)),
        ]),
      ),
    );

    if (!expanded) return Glass(padding: const EdgeInsets.fromLTRB(10, 8, 12, 8), child: header);

    final last = lastPerformance(controller.repo.history(), row.exerciseId);
    final notes = controller.notesFor(row.exerciseId);
    final warm = row.sets.where((s) => s.kind == SetKind.warmup).toList();
    final work = row.sets.where((s) => s.kind == SetKind.work).toList();
    final editable = row.status == ExerciseStatus.open;
    final canDone = row.canMarkDone;
    bool hasUnlogged(SetKind k) => row.sets.any((s) => s.kind == k && !s.isLogged);

    Widget pair(SetKind kind, String label) => Expanded(
          child: Row(children: [
            SizedBox(
              width: 48,
              child: _SecondaryButton(
                label: '−',
                icon: Icons.remove,
                semanticLabel: 'Remove last unlogged ${kind == SetKind.warmup ? 'warm-up' : 'work set'}',
                onTap: hasUnlogged(kind) ? () => controller.removeLastSet(row.id, kind) : null,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: _SecondaryButton(label: label, onTap: () => controller.addSet(row.id, kind))),
          ]),
        );

    return Glass(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: header),
          IconButton(
            tooltip: 'More',
            onPressed: () => _menu(context),
            icon: Icon(Icons.more_vert, color: c.textMuted),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(measureDescription(row.measure), style: text.bodyMedium),
            if (ex.tip != null) Text(ex.tip!, style: text.bodySmall!.copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: 6),
            Text(
              last == null
                  ? 'No history yet'
                  : 'Last (${daysAgo(last.date, now)}): ${last.workSets.map((s) => fmtSet(s, last.exercise.measure, settings)).join('  ·  ')}',
              style: text.bodySmall,
            ),
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Icon(n.pinned ? Icons.push_pin : Icons.sticky_note_2_outlined, size: 16, color: c.restGold),
                  const SizedBox(width: 6),
                  Expanded(child: Text(n.text, style: text.bodyMedium!.copyWith(color: c.restGold))),
                  IconButton(
                    tooltip: 'Remove note',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => controller.deleteNote(n),
                    icon: Icon(Icons.close, size: 18, color: c.textFaint),
                  ),
                ]),
              ),
            TextButton(
              onPressed: () => _addNote(context),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 40)),
              child: Text('+ Note for next time', style: text.bodySmall!.copyWith(color: c.restGold)),
            ),
          ]),
        ),
        if (warm.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('WARM-UP', style: text.labelSmall!.copyWith(color: c.textMuted)),
          for (final (i, s) in warm.indexed)
            SetRow(key: ValueKey(s.id.value), controller: controller, row: row, set: s, label: 'W${i + 1}', editable: editable),
        ],
        const SizedBox(height: 12),
        Text('WORK', style: text.labelSmall!.copyWith(color: c.accent)),
        for (final (i, s) in work.indexed)
          SetRow(key: ValueKey(s.id.value), controller: controller, row: row, set: s, label: 'S${i + 1}', editable: editable),
        if (editable) ...[
          const SizedBox(height: 16),
          Row(children: [
            pair(SetKind.warmup, '+ WARM-UP'),
            const SizedBox(width: 12),
            pair(SetKind.work, '+ WORK SET'),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: _SecondaryButton(label: 'SKIP', onTap: () => controller.skip(row.id), color: c.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Semantics(
                button: true,
                enabled: canDone,
                label: 'Exercise done',
                child: GestureDetector(
                  onTap: canDone ? () => controller.markDone(row.id) : null,
                  // Släckt tills varje set är loggat (Niklas 2026-10-03).
                  child: Raised(
                    material: canDone ? c.raisedActive : c.raisedIdle,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check, size: 18, color: canDone ? c.textStrong : c.textFaint),
                      const SizedBox(width: 8),
                      Text('DONE', style: text.labelLarge!.copyWith(color: canDone ? c.textStrong : c.textFaint)),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
          if (!canDone)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Log every set — or remove the ones you skip', style: text.labelSmall, textAlign: TextAlign.center),
            ),
        ] else ...[
          const SizedBox(height: 12),
          _SecondaryButton(label: 'REOPEN', onTap: () => controller.reopen(row.id)),
        ],
      ]),
    );
  }

  Future<void> _addNote(BuildContext context) async {
    final textCtl = TextEditingController();
    var pinned = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Note'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: textCtl, autofocus: true, maxLines: 3, decoration: const InputDecoration(hintText: 'e.g. raise 2.5 kg')),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: pinned,
              onChanged: (v) => setState(() => pinned = v ?? false),
              title: const Text('Pin — keep until I remove it'),
            ),
            Text(pinned ? 'Stays on this exercise.' : 'Shown next session, then moves to history.',
                style: Theme.of(ctx).textTheme.bodySmall),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true) await controller.addNote(row.exerciseId, textCtl.text, pinned: pinned);
    textCtl.dispose();
  }

  Future<void> _menu(BuildContext context) async {
    final custom = controller.repo.customExercises().values.toList();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.swap_horiz), title: const Text('Swap — this session only'), onTap: () => Navigator.pop(ctx, 'temp')),
          if (!row.isExtra)
            ListTile(leading: const Icon(Icons.swap_calls), title: const Text('Swap — permanently'), onTap: () => Navigator.pop(ctx, 'perm')),
          if (row.isExtra)
            ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Remove extra'), onTap: () => Navigator.pop(ctx, 'remove')),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'remove') {
      controller.removeExtra(row.id);
      return;
    }
    final id = await pickExercise(context, title: choice == 'perm' ? 'Swap permanently' : 'Swap for today', custom: custom);
    if (id == null) return;
    if (choice == 'perm') {
      await controller.swapPermanently(row.id, id);
    } else {
      controller.swapTemporarily(row.id, id);
    }
  }
}

class SetRow extends StatefulWidget {
  const SetRow({super.key, required this.controller, required this.row, required this.set, required this.label, required this.editable});

  final WorkoutController controller;
  final WorkoutExercise row;
  final SetEntry set;
  final String label;
  final bool editable;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final Map<InputField, TextEditingController> _ctl;
  late final List<InputField> _fields = inputFields(widget.row.measure);

  /// Målet anges i reps om mätsättet har reps, annars i tid; annars inget mål.
  late final InputField? _goalField = widget.row.measure.fields.contains(SetField.reps)
      ? InputField.reps
      : (widget.row.measure.fields.contains(SetField.secs) ? InputField.secs : null);
  late final TextEditingController _goal;

  UserSettings get _settings => widget.controller.repo.settings();

  @override
  void initState() {
    super.initState();
    _ctl = {for (final f in _fields) f: TextEditingController(text: displayValue(f, widget.set.values, widget.row.measure, _settings))};
    _goal = TextEditingController(text: _goalText(widget.set));
  }

  String _goalText(SetEntry s) {
    final f = _goalField, t = s.target;
    return (f == null || t == null) ? '' : displayValue(f, t, widget.row.measure, _settings);
  }

  @override
  void didUpdateWidget(SetRow old) {
    super.didUpdateWidget(old);
    // FAIL av → målet är borta; nästa FAIL börjar med tomt fält.
    if (old.set.target != null && widget.set.target == null) _goal.text = '';
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    _goal.dispose();
    super.dispose();
  }

  void _changed(InputField f, String text) {
    final s = widget.controller.workout.exercises.firstWhere((r) => r.id == widget.row.id).sets.firstWhere((x) => x.id == widget.set.id);
    widget.controller.setValues(widget.row.id, widget.set.id, applyInput(f, text, s.values, widget.row.measure, _settings));
  }

  /// Tomt fält = FAIL utan mål (målet tas bort, markeringen ligger kvar).
  void _goalChanged(String text) {
    final f = _goalField;
    if (f == null) return;
    final t = applyInput(f, text, SetValues.empty, widget.row.measure, _settings);
    widget.controller.setTarget(widget.row.id, widget.set.id, t);
  }

  InputDecoration _box(ChainTheme c, TextTheme text, {String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: text.titleMedium!.copyWith(color: c.textFaint),
        filled: true,
        fillColor: c.background,
        contentPadding: EdgeInsets.zero,
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.borderStrong), borderRadius: BorderRadius.zero),
        disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.zero),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: c.accent), borderRadius: BorderRadius.zero),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final s = widget.set;
    final locked = s.isLogged || !widget.editable;
    final failed = s.isLogged && s.target != null;
    final missed = s.isLogged && s.missed(widget.row.measure);
    final ex = widget.controller.exerciseOf(widget.row);

    final main = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 44,
        child: InkWell(
          onTap: widget.editable ? () => _removeSet(context) : null,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(widget.label, style: text.titleMedium!.copyWith(color: s.kind == SetKind.warmup ? c.textMuted : c.textStrong)),
          ),
        ),
      ),
      for (final f in _fields) ...[
        Expanded(
          child: Column(children: [
            SizedBox(
              height: 48,
              child: TextField(
                controller: _ctl[f],
                enabled: !locked,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: text.titleMedium!.copyWith(color: locked ? c.textMuted : c.textStrong),
                onChanged: (v) => _changed(f, v),
                decoration: _box(c, text, hint: _hint(f)),
              ),
            ),
            const SizedBox(height: 4),
            Text(fieldLabel(f, widget.row.measure, _settings), style: text.labelSmall),
          ]),
        ),
        const SizedBox(width: 6),
      ],
      if (ex.unilateral)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Semantics(
            button: true,
            label: 'Side',
            child: GestureDetector(
              // Ingen sida → L → R → ingen sida (Niklas 2026-10-03).
              onTap: locked ? null : () => widget.controller.cycleSide(widget.row.id, s.id),
              child: Container(
                width: 36,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: c.borderStrong)),
                child: Text(s.side == Side.right ? 'R' : s.side == Side.left ? 'L' : 'L/R', style: text.labelSmall!.copyWith(color: c.accent)),
              ),
            ),
          ),
        ),
      Column(children: [
        GestureDetector(
          onTap: widget.editable ? () => widget.controller.toggleLog(widget.row.id, s.id) : null,
          child: SizedBox(
            width: 72,
            height: 48,
            child: Raised(
              material: s.isLogged ? c.raisedDone : c.raisedActive,
              padding: EdgeInsets.zero,
              child: Center(
                child: s.isLogged
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check, size: 20, color: missed ? c.restGold : c.success),
                        if (missed) ...[
                          const SizedBox(width: 4),
                          // Saira saknar ✗ (som ✓) — ikon när inget mål finns.
                          if (_missedText(s) case final t?)
                            Text(t, style: text.labelLarge!.copyWith(color: c.restGold, fontSize: 13))
                          else
                            Icon(Icons.close, size: 18, color: c.restGold),
                        ],
                      ])
                    : Text('LOG', style: text.labelLarge!.copyWith(fontSize: 13)),
              ),
            ),
          ),
        ),
        // FAIL finns bara på loggade set: man vet först efteråt att det gick fel.
        if (s.isLogged) ...[
          const SizedBox(height: 6),
          Semantics(
            button: true,
            selected: failed,
            label: 'Fail',
            child: GestureDetector(
              onTap: widget.editable ? () => widget.controller.toggleFailed(widget.row.id, s.id) : null,
              child: Container(
                width: 72,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.background,
                  border: Border.all(color: failed ? c.restGold : c.border),
                ),
                child: Text('FAIL', style: text.labelSmall!.copyWith(color: failed ? c.restGold : c.textMuted, letterSpacing: 1.5)),
              ),
            ),
          ),
        ],
      ]),
    ]);

    final goalField = _goalField;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        main,
        // GOAL visas när FAIL är tryckt — valfritt: "siktade på 4" ger 3/4.
        if (failed && goalField != null)
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 6),
            child: Row(children: [
              Text('GOAL', style: text.labelSmall!.copyWith(color: c.restGold)),
              const SizedBox(width: 10),
              SizedBox(
                width: 72,
                height: 44,
                child: TextField(
                  controller: _goal,
                  enabled: widget.editable,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  style: text.titleMedium!.copyWith(color: c.textStrong),
                  onChanged: _goalChanged,
                  decoration: _box(c, text, hint: '—'),
                ),
              ),
              const SizedBox(width: 8),
              Text(fieldLabel(goalField, widget.row.measure, _settings), style: text.labelSmall),
              const SizedBox(width: 10),
              Expanded(child: Text('optional', style: text.labelSmall!.copyWith(color: c.textFaint))),
            ]),
          ),
      ]),
    );
  }

  String _hint(InputField f) => switch (f) {
        InputField.forced || InputField.extra => '0',
        _ => '—',
      };

  /// "3/4" när ett mål finns (reps eller tid i fältets enhet), annars null.
  String? _missedText(SetEntry s) {
    final f = _goalField, t = s.target;
    if (f == null || t == null) return null;
    final goal = displayValue(f, t, widget.row.measure, _settings);
    if (goal.isEmpty) return null;
    final got = displayValue(f, s.values, widget.row.measure, _settings);
    return '${got.isEmpty ? '0' : got}/$goal';
  }

  Future<void> _removeSet(BuildContext context) async {
    if (widget.set.isLogged) {
      widget.controller.removeSet(widget.row.id, widget.set.id); // ger felet "Unlog the set before removing it"
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove set ${widget.label}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) widget.controller.removeSet(widget.row.id, widget.set.id);
  }
}
