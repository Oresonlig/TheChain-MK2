/// "Copy" av ett avslutat pass — samma format som MK1 (buildCopyLines) så att
/// det fungerar som förut på Instagram, till polarna eller till en PT-Claude.
library;

import 'dart:math';

import '../domain/domain.dart';
import 'units.dart';

/// MK1:s etiketter per tidsspann (SESSION_LABELS).
const _labels = <List<String>>[
  ['Morning Session', 'Dawn Patrol', 'Early Bird', 'Sunrise Lift', 'First Light', 'Respawn', 'Sunbreak'], // 04–10
  ['High Noon', 'Daily Grind', 'Lunch Hour', 'Midday Burn', 'Noon Strike', 'Side Quest', 'Daily Quest'], // 11–13
  ['Afternoon Delight', 'Siesta Skip', 'Tea Time', 'Coffee Crush', 'Post Refeed', 'Daily Reset', 'Loot Run'], // 14–16
  ['Crowd Work', 'Happy Hour', 'After Hours', 'Commuter Hours', 'Rush Hour', 'Raid Time', 'Lobby Full'], // 17–19
  ['Prime Time', 'Sweet Spot', 'Headliner', 'Main Event', 'Showcase', 'Boss Fight', 'Final Boss'], // 20–21
  ['Evening Session', 'Last Call', 'Curtain Call', 'Late Show', 'Final Round', 'Quicksave', 'Last Save'], // 22–23
  ['Night Owl', 'Witching Hour', 'Graveyard Shift', 'Lights Out', "Insomniac's Lift", 'Hardcore Mode', 'No-Sleep Mode'], // 00–03
];

String sessionLabel(DateTime t, Random rnd) {
  final h = t.hour;
  final bucket = h >= 4 && h <= 10
      ? 0
      : h <= 13 && h >= 11
          ? 1
          : h >= 14 && h <= 16
              ? 2
              : h >= 17 && h <= 19
                  ? 3
                  : h >= 20 && h <= 21
                      ? 4
                      : h >= 22
                          ? 5
                          : 6;
  final arr = _labels[bucket];
  return arr[rnd.nextInt(arr.length)];
}

String _date(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
}

String buildCopyText({
  required Workout workout,
  required String sessionName,
  required String Function(ExerciseId) nameOf,
  required UserSettings settings,
  Random? random,
}) {
  final t = workout.finishedAt ?? workout.startedAt;
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final lines = <String>[
    '💪 The Chain — $sessionName',
    '📅 ${_date(t)}',
    '🕒 $hm — ${sessionLabel(t, random ?? Random())}',
    '',
  ];
  for (final ex in workout.exercises) {
    if (ex.status == ExerciseStatus.skipped) continue;
    final sets = ex.sets.where((s) => s.isLogged).toList();
    if (sets.isEmpty) continue;
    lines.add('${nameOf(ex.exerciseId)}${ex.isExtra ? ' +' : ''}');
    var w = 0, s = 0;
    for (final set in [...sets.where((x) => x.kind == SetKind.warmup), ...sets.where((x) => x.kind == SetKind.work)]) {
      final line = fmtSet(set, ex.measure, settings);
      final side = set.side == null ? '' : ' (${set.side == Side.left ? 'L' : 'R'})';
      if (set.kind == SetKind.warmup) {
        lines.add('  W${++w}: $line$side');
      } else {
        lines.add('  S${++s}: $line$side');
      }
    }
    lines.add('');
  }
  // Sist i innehållet (Niklas 2026-10-05): guld för PT-Claude.
  if (workout.note case final n?) lines..add('📝 $n')..add('');
  lines
    ..add('thechain.training')
    ..add('')
    ..add('#thechain')
    ..add('#gymlife');
  return lines.join('\n');
}
