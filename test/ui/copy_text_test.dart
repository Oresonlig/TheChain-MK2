import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';
import 'package:the_chain/ui/copy_text.dart';

SetEntry s(SetKind k, SetValues v, {SetValues? target, bool excluded = false, Side? side}) =>
    SetEntry(id: SetId('$k$v'), kind: k, values: v, target: target, isLogged: true, excludeFromRecords: excluded, side: side);

void main() {
  test('samma format som MK1: rubrik, datum, klockslag + etikett, W/S-rader, hashtags', () {
    final w = Workout(
      id: const WorkoutId('w'),
      sessionId: const SessionId('B'),
      startedAt: DateTime(2026, 10, 2, 19),
      finishedAt: DateTime(2026, 10, 2, 20, 15),
      exercises: [
        WorkoutExercise(
          id: 'r1',
          exerciseId: const ExerciseId('ex_deadlift'),
          slotId: const SlotId('B2'),
          measure: Measure.weight,
          status: ExerciseStatus.done,
          sets: [
            s(SetKind.work, const SetValues(weight: 180, reps: 3), target: const SetValues(reps: 4)),
            s(SetKind.warmup, const SetValues(weight: 100, reps: 5)),
          ],
        ),
        WorkoutExercise(
          id: 'r2',
          exerciseId: const ExerciseId('ex_dead_hang'),
          slotId: const SlotId('B1'),
          measure: Measure.bodyweightTimed,
          status: ExerciseStatus.done,
          sets: [s(SetKind.work, const SetValues(extra: 10, secs: 60))],
        ),
        const WorkoutExercise(id: 'r3', exerciseId: ExerciseId('ex_skip'), measure: Measure.weight, status: ExerciseStatus.skipped),
        WorkoutExercise(
          id: 'r4',
          exerciseId: const ExerciseId('ex_row'),
          measure: Measure.weight,
          status: ExerciseStatus.done,
          sets: [s(SetKind.work, const SetValues(weight: 40, reps: 10), side: Side.left)],
        ), // ingen plats = extraövning → "+"
      ],
    );
    final text = buildCopyText(
      workout: w,
      sessionName: 'Back Heavy + Biceps',
      nameOf: (id) => {'ex_deadlift': 'Deadlift', 'ex_dead_hang': 'Dead Hang', 'ex_row': 'Unilateral Row (Cable)'}[id.value] ?? id.value,
      settings: const UserSettings(),
      random: Random(1),
    );
    final lines = text.split('\n');
    expect(lines[0], '💪 The Chain — Back Heavy + Biceps');
    expect(lines[1], '📅 Fri, 2 Oct');
    expect(lines[2], startsWith('🕒 20:15 — '));
    expect(text, contains('Deadlift\n  W1: 100 kg × 5\n  S1: 180 kg × 3/4\n'));
    expect(text, contains('Dead Hang\n  S1: BW + 10 kg · 60 s\n'));
    expect(text, contains('Unilateral Row (Cable) +\n  S1: 40 kg × 10 (L)'));
    expect(text, isNot(contains('ex_skip')));
    expect(text, endsWith('thechain.training\n\n#thechain\n#gymlife'));
  });

  test('etiketten följer tidsspannet', () {
    expect(sessionLabel(DateTime(2026, 1, 1, 7), Random(0)),
        isIn(['Morning Session', 'Dawn Patrol', 'Early Bird', 'Sunrise Lift', 'First Light', 'Respawn', 'Sunbreak']));
    expect(sessionLabel(DateTime(2026, 1, 1, 20, 30), Random(0)),
        isIn(['Prime Time', 'Sweet Spot', 'Headliner', 'Main Event', 'Showcase', 'Boss Fight', 'Final Boss']));
    expect(sessionLabel(DateTime(2026, 1, 1, 2), Random(0)),
        isIn(['Night Owl', 'Witching Hour', 'Graveyard Shift', 'Lights Out', "Insomniac's Lift", 'Hardcore Mode', 'No-Sleep Mode']));
  });
}
