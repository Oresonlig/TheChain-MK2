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

  /// Öppna grupper. Kollapsade som standard (Niklas 2026-10-03); en sökning
  /// visar alla träffar oavsett.
  final _open = <String>{};

  void _toggle(String label) => setState(() => _open.contains(label) ? _open.remove(label) : _open.add(label));

  List<Widget> _group(String label, List<Exercise> items) {
    final open = _q.isNotEmpty || _open.contains(label);
    return [
      GroupHeader(label, count: items.length, open: open, onTap: _q.isNotEmpty ? null : () => _toggle(label)),
      if (open) for (final e in items) _Row(e),
    ];
  }

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
              if (lib.any((e) => e.group == g)) ..._group(groupLabel(g), lib.where((e) => e.group == g).toList()),
            if (mine.isNotEmpty) ..._group('Your exercises', mine),
          ]),
        ),
      ]),
    );
  }
}

/// Grupprubrik: hela raden är träffytan (≥ 52 px), pil + antal till höger.
class GroupHeader extends StatelessWidget {
  const GroupHeader(this.label, {super.key, required this.count, required this.open, this.onTap, this.padding = 16});
  final String label;
  final int count;
  final bool open;
  final VoidCallback? onTap;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      expanded: open,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Row(children: [
              Expanded(child: Text(label.toUpperCase(), style: text.labelSmall!.copyWith(color: c.accent))),
              Text('$count', style: text.labelSmall),
              const SizedBox(width: 6),
              Icon(open ? Icons.expand_less : Icons.expand_more, color: c.textFaint, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
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
