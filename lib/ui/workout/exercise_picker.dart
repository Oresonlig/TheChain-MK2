/// Övningsväljare (byte, extraövning och programbyggaren): sök + grupper i
/// alfabetisk ordning, egna övningar sist (MK1 3.85.0). Senast använda överst,
/// flerval i byggaren och "Create" direkt från sökningen (Niklas 2026-10-04).
library;

import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../theme/chain_theme.dart';
import '../../theme/surfaces.dart';
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

/// Skapar en egen övning med [name] som förslag (egenskapsbladet). Null = avbrutet.
typedef CreateExercise = Future<Exercise?> Function(BuildContext context, String name);

/// Övningar från de senaste passen, nyast först, utan dubbletter.
List<ExerciseId> recentExercises(Iterable<HistoryEntry> history, {int max = 8}) {
  final entries = history.whereType<WorkoutEntry>().toList()..sort((a, b) => b.date.compareTo(a.date));
  final out = <ExerciseId>[];
  for (final e in entries) {
    for (final x in e.workout.exercises) {
      if (x.status == ExerciseStatus.skipped || out.contains(x.exerciseId)) continue;
      out.add(x.exerciseId);
      if (out.length >= max) return out;
    }
  }
  return out;
}

/// En övning (byte, extra).
Future<ExerciseId?> pickExercise(
  BuildContext context, {
  required String title,
  required List<Exercise> custom,
  List<ExerciseId> recent = const [],
  CreateExercise? onCreate,
}) async {
  final picked = await Navigator.of(context).push<List<ExerciseId>>(MaterialPageRoute(
    builder: (_) => _Picker(title: title, custom: custom, recent: recent, onCreate: onCreate, multi: false),
  ));
  return picked?.firstOrNull;
}

/// Flera övningar i ett svep (byggaren). Tom lista = inget valt.
Future<List<ExerciseId>> pickExercises(
  BuildContext context, {
  required String title,
  required List<Exercise> custom,
  List<ExerciseId> recent = const [],
  Set<ExerciseId> already = const {},
  CreateExercise? onCreate,
}) async =>
    await Navigator.of(context).push<List<ExerciseId>>(MaterialPageRoute(
      builder: (_) => _Picker(title: title, custom: custom, recent: recent, already: already, onCreate: onCreate, multi: true),
    )) ??
    const [];

class _Picker extends StatefulWidget {
  const _Picker({
    required this.title,
    required this.custom,
    required this.recent,
    required this.multi,
    this.already = const {},
    this.onCreate,
  });
  final String title;
  final List<Exercise> custom;
  final List<ExerciseId> recent;
  final bool multi;

  /// Redan i passet — visas med en etikett, går ändå att välja.
  final Set<ExerciseId> already;
  final CreateExercise? onCreate;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  static const _recentLabel = 'Recent';
  String _q = '';
  late final List<Exercise> _custom = [...widget.custom.where((e) => !e.archived)];

  /// Valda, i den ordning de trycktes (= ordningen de läggs i passet).
  final _picked = <ExerciseId>[];

  /// Öppna grupper. Kollapsade som standard (Niklas 2026-10-03) — utom
  /// "Recent", som är skälet att öppna väljaren snabbt. En sökning visar alla
  /// träffar oavsett.
  final _open = <String>{_recentLabel};

  void _toggle(String label) => setState(() => _open.contains(label) ? _open.remove(label) : _open.add(label));

  void _tap(ExerciseId id) {
    if (!widget.multi) {
      Navigator.pop(context, [id]);
      return;
    }
    setState(() => _picked.contains(id) ? _picked.remove(id) : _picked.add(id));
  }

  Future<void> _create() async {
    final e = await widget.onCreate!(context, _q.trim());
    if (e == null || !mounted) return;
    setState(() => _custom.add(e));
    _tap(e.id);
  }

  List<Widget> _group(String label, List<Exercise> items) {
    final open = _q.isNotEmpty || _open.contains(label);
    return [
      GroupHeader(label, count: items.length, open: open, onTap: _q.isNotEmpty ? null : () => _toggle(label)),
      if (open)
        for (final e in items)
          _Row(
            e,
            multi: widget.multi,
            picked: _picked.contains(e.id),
            inSession: widget.already.contains(e.id),
            onTap: () => _tap(e.id),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final q = _q.trim().toLowerCase();
    bool match(Exercise e) => q.isEmpty || e.name.toLowerCase().contains(q);
    // En egen övning med samma namn som en senare biblioteksövning har samma id
    // (slug) och vinner i resolveExercise — visa den bara en gång, som egen.
    final mineIds = {for (final e in _custom) e.id};
    final lib = exerciseLibrary.where((e) => match(e) && !mineIds.contains(e.id)).toList();
    final mine = _custom.where(match).toList()..sort((a, b) => a.name.compareTo(b.name));
    final byId = {for (final e in [...exerciseLibrary, ..._custom]) e.id: e};
    final recent = q.isNotEmpty ? const <Exercise>[] : [for (final id in widget.recent) ?byId[id]];
    final exact = [...lib, ...mine].any((e) => e.name.toLowerCase() == q);

    return ChainScaffold(
      ambient: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
          child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back, color: c.textMuted)),
            Expanded(child: Text(widget.title, style: text.titleMedium, overflow: TextOverflow.ellipsis)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            autofocus: true,
            textCapitalization: TextCapitalization.words,
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
            // Hittas inget exakt: skapa direkt med det som skrevs.
            if (widget.onCreate != null && q.isNotEmpty && !exact)
              ListTile(
                minTileHeight: 52,
                leading: Icon(Icons.add, color: c.accent),
                title: Text('Create "${_q.trim()}"', style: text.bodyMedium!.copyWith(color: c.accent)),
                onTap: _create,
              ),
            if (recent.isNotEmpty) ..._group(_recentLabel, recent),
            for (final g in _groupOrder)
              if (lib.any((e) => e.group == g)) ..._group(groupLabel(g), lib.where((e) => e.group == g).toList()),
            if (mine.isNotEmpty) ..._group('Your exercises', mine),
          ]),
        ),
        if (widget.multi)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: GestureDetector(
              onTap: _picked.isEmpty ? null : () => Navigator.pop(context, List.of(_picked)),
              child: Raised(
                material: _picked.isEmpty ? c.raisedIdle : c.raisedActive,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    _picked.isEmpty ? 'SELECT EXERCISES' : 'ADD ${_picked.length}',
                    style: text.labelLarge!.copyWith(color: _picked.isEmpty ? c.textFaint : c.textStrong),
                  ),
                ),
              ),
            ),
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
  const _Row(this.e, {required this.multi, required this.picked, required this.inSession, required this.onTap});
  final Exercise e;
  final bool multi, picked, inSession;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return ListTile(
      minTileHeight: 52,
      title: Text(e.name, style: text.bodyMedium!.copyWith(color: c.textStrong)),
      subtitle: inSession ? Text('Already in this session', style: text.labelSmall) : null,
      trailing: multi
          ? Icon(picked ? Icons.check_box : Icons.check_box_outline_blank, color: picked ? c.accent : c.textFaint)
          : null,
      onTap: onTap,
    );
  }
}
