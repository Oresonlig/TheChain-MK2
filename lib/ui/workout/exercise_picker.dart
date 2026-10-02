/// Övningsväljare (byte och extraövning): sök + grupper i alfabetisk ordning,
/// egna övningar sist (MK1 3.85.0).
library;

import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../nanosuit_scaffold.dart';

const _groupOrder = [
  MuscleGroup.arms,
  MuscleGroup.back,
  MuscleGroup.cardio,
  MuscleGroup.chest,
  MuscleGroup.core,
  MuscleGroup.legs,
  MuscleGroup.shoulders,
  MuscleGroup.traps,
  MuscleGroup.other,
];

String groupLabel(MuscleGroup g) => g == MuscleGroup.other ? 'Other' : g.name[0].toUpperCase() + g.name.substring(1);

Future<ExerciseId?> pickExercise(BuildContext context, {required String title, required List<Exercise> custom}) =>
    Navigator.of(context).push<ExerciseId>(MaterialPageRoute(builder: (_) => _Picker(title: title, custom: custom)));

class _Picker extends StatefulWidget {
  const _Picker({required this.title, required this.custom});
  final String title;
  final List<Exercise> custom;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final q = _q.toLowerCase();
    bool match(Exercise e) => q.isEmpty || e.name.toLowerCase().contains(q);
    final lib = exerciseLibrary.where(match).toList();
    final mine = widget.custom.where(match).toList()..sort((a, b) => a.name.compareTo(b.name));

    return ChainScaffold(
      ambient: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
          child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back, color: c.textMuted)),
            Text(widget.title, style: text.titleMedium),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _q = v),
            style: text.bodyMedium!.copyWith(color: c.textStrong),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, color: c.textMuted),
              hintText: 'Search exercises',
              hintStyle: text.bodySmall,
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.borderStrong), borderRadius: BorderRadius.zero),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: c.accent), borderRadius: BorderRadius.zero),
            ),
          ),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            for (final g in _groupOrder)
              if (lib.any((e) => e.group == g)) ...[
                _Header(groupLabel(g)),
                for (final e in lib.where((e) => e.group == g)) _Row(e),
              ],
            if (mine.isNotEmpty) ...[
              const _Header('Your exercises'),
              for (final e in mine) _Row(e),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall!.copyWith(color: context.chain.accent)),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.e);
  final Exercise e;

  @override
  Widget build(BuildContext context) => ListTile(
        minTileHeight: 52,
        title: Text(e.name, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: context.chain.textStrong)),
        onTap: () => Navigator.pop(context, e.id),
      );
}
