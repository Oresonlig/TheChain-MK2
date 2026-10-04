/// Övningens egenskaper — ett blad nerifrån, inte en egen skärm (Niklas
/// 2026-10-04: MK1:s byggare var "skitmånga subfönster"). Samma blad skapar en
/// ny egen övning. Egenskaperna gäller ÖVNINGEN, i alla pass.
library;

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
import '../format.dart';
import '../units.dart';
import '../workout/exercise_picker.dart' show groupLabel;

/// Redigerar [exercise], eller skapar en ny egen övning med [newName] som
/// förslag. Returnerar den sparade övningen, null om bladet stängdes.
Future<Exercise?> showExerciseSheet(BuildContext context, {required AppController app, Exercise? exercise, String newName = ''}) =>
    showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ExerciseSheet(app: app, exercise: exercise, newName: newName),
    );

class _ExerciseSheet extends StatefulWidget {
  const _ExerciseSheet({required this.app, required this.exercise, required this.newName});
  final AppController app;
  final Exercise? exercise;
  final String newName;

  @override
  State<_ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends State<_ExerciseSheet> {
  // Ingen dispose: bladets stängningsanimation läser fälten efter pop.
  late final _name = TextEditingController(text: widget.exercise?.name ?? widget.newName);
  late final _tip = TextEditingController(text: widget.exercise?.tip ?? '');
  late MuscleGroup _group = widget.exercise?.group ?? MuscleGroup.other;
  late Measure _measure = widget.exercise?.measure ?? Measure.weight;
  late SetScheme _scheme = widget.exercise?.scheme ?? SetScheme.standard;
  late bool _unilateral = widget.exercise?.unilateral ?? false;
  String? _error;
  bool _saving = false;

  bool get _isNew => widget.exercise == null;
  bool get _editsIdentity => _isNew || widget.exercise!.isCustom;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final tip = _tip.text.trim();
      final Exercise saved;
      if (_isNew) {
        saved = await widget.app.createExercise(Exercise(
          id: const ExerciseId('new'),
          name: _name.text,
          group: _group,
          measure: _measure,
          scheme: _scheme,
          unilateral: _unilateral,
          tip: tip.isEmpty ? null : tip,
        ));
      } else {
        final e = widget.exercise!;
        final name = _name.text.trim();
        if (e.isCustom && name.isEmpty) throw const WorkoutError('Give the exercise a name');
        saved = e.isCustom
            ? e.copyWith(name: name, group: _group, measure: _measure, scheme: _scheme, unilateral: _unilateral, tip: tip, clearTip: tip.isEmpty)
            : e.copyWith(measure: _measure, scheme: _scheme, unilateral: _unilateral);
        await widget.app.saveExercise(saved);
      }
      if (mounted) Navigator.pop(context, saved);
    } on WorkoutError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive() async {
    try {
      await widget.app.archiveExercise(widget.exercise!.id);
      if (mounted) Navigator.pop(context);
    } on WorkoutError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final repo = widget.app.repo;
    final e = widget.exercise;
    // Bytt mätsätt nollställer rekordet för det nya mätsättet (records.dart).
    final record = (e == null || repo == null || _measure == e.measure) ? null : repo.records(includeHidden: true)[e.id];
    final unit = repo?.settings().weightUnit ?? WeightUnit.kg;

    Widget label(String s) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(s, style: text.labelSmall),
        );
    InputDecoration field(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: text.bodySmall,
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.borderStrong), borderRadius: BorderRadius.zero),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: c.accent), borderRadius: BorderRadius.zero),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(_isNew ? 'NEW EXERCISE' : e!.name.toUpperCase(), style: text.titleMedium!.copyWith(letterSpacing: 2)),
          if (!_editsIdentity) Text('Library exercise · changes apply in every session', style: text.bodySmall),
          if (_editsIdentity) ...[
            label('NAME'),
            TextField(
              controller: _name,
              autofocus: _isNew && _name.text.isEmpty,
              textCapitalization: TextCapitalization.words,
              style: text.bodyMedium!.copyWith(color: c.textStrong),
              decoration: field('e.g. Cable Row'),
            ),
            label('MUSCLE GROUP'),
            DropdownButton<MuscleGroup>(
              value: _group,
              isExpanded: true,
              items: [for (final g in MuscleGroup.values) DropdownMenuItem(value: g, child: Text(groupLabel(g)))],
              onChanged: (g) => setState(() => _group = g ?? _group),
            ),
          ],
          label('MEASURED AS'),
          DropdownButton<Measure>(
            value: _measure,
            isExpanded: true,
            items: [for (final m in Measure.values) DropdownMenuItem(value: m, child: Text(measureDescription(m)))],
            onChanged: (m) => setState(() => _measure = m ?? _measure),
          ),
          // Tydlig indikator: rekordet börjar om (Niklas 2026-10-04).
          if (e != null && _measure != e.measure)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: c.fail)),
              child: Text(
                record == null
                    ? 'Records restart for this measure. Old sessions stay in history as logged.'
                    : 'Your record ${fmtRecord(record, unit)} stops counting — records restart for this measure. '
                        'Old sessions stay in history. Switch back to get it back.',
                style: text.bodySmall!.copyWith(color: c.fail),
              ),
            ),
          label('SETS'),
          Row(children: [
            for (final (i, s) in SetScheme.values.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              _Choice(
                label: switch (s) {
                  SetScheme.standard => 'STANDARD',
                  SetScheme.ramp => 'RAMP',
                  SetScheme.singles => 'SINGLES',
                },
                on: _scheme == s,
                onTap: () => setState(() => _scheme = s),
              ),
            ],
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              switch (_scheme) {
                SetScheme.standard => 'Warm-up sets, then work sets.',
                SetScheme.ramp => 'Heavier every set, no separate warm-up.',
                SetScheme.singles => 'Heavy singles after a warm-up.',
              },
              style: text.bodySmall,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _unilateral,
            onChanged: (v) => setState(() => _unilateral = v),
            title: Text('One side at a time', style: text.titleMedium),
            subtitle: Text('Log left and right (L/R)', style: text.bodySmall),
          ),
          if (_editsIdentity) ...[
            label('TIP (OPTIONAL)'),
            TextField(
              controller: _tip,
              textCapitalization: TextCapitalization.sentences,
              style: text.bodyMedium!.copyWith(color: c.textStrong),
              decoration: field('A technique cue shown in the session'),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: text.bodyMedium!.copyWith(color: c.fail)),
            ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Raised(
              material: c.raisedActive,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text(_isNew ? 'CREATE' : 'SAVE', style: text.labelLarge)),
            ),
          ),
          if (e != null && e.isCustom)
            Center(
              child: TextButton(
                onPressed: _archive,
                child: Text('Remove exercise', style: text.bodySmall),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: on
              ? Raised(material: c.raisedActive, padding: EdgeInsets.zero, child: Center(child: Text(label, style: text.labelLarge!.copyWith(fontSize: 12))))
              : DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: c.borderStrong)),
                  child: Center(child: Text(label, style: text.labelLarge!.copyWith(fontSize: 12, color: c.textMuted))),
                ),
        ),
      ),
    );
  }
}
