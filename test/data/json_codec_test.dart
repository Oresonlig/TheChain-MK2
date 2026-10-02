import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/data/json_codec.dart';
import 'package:the_chain/domain/domain.dart';

/// Kör genom riktig JSON-text (som i Supabase/lokalt), inte bara Map.
Json viaText(Json j) => (jsonDecode(jsonEncode(j)) as Map).cast<String, Object?>();

void main() {
  final start = DateTime(2026, 10, 2, 18), end = DateTime(2026, 10, 2, 19, 5);

  test('pass med alla fältsorter överlever JSON', () {
    final w = Workout(
      id: const WorkoutId('w1'),
      sessionId: const SessionId('B'),
      startedAt: start,
      finishedAt: end,
      exercises: const [
        WorkoutExercise(
          id: 'r1',
          exerciseId: ExerciseId('ex_dead_hang'),
          measure: Measure.bodyweightTimed,
          slotId: SlotId('B1'),
          temporarySwapFrom: ExerciseId('ex_chins_supinated'),
          status: ExerciseStatus.done,
          sets: [
            SetEntry(
              id: SetId('s1'),
              kind: SetKind.work,
              values: SetValues(extra: 10, secs: 70),
              target: SetValues(secs: 90),
              isLogged: true,
              bodyweightKg: 100.3,
              side: Side.right,
            ),
            SetEntry(id: SetId('s2'), kind: SetKind.warmup, excludeFromRecords: true),
          ],
        ),
        WorkoutExercise(id: 'r2', exerciseId: ExerciseId('ex_running'), measure: Measure.run, status: ExerciseStatus.skipped),
      ],
    );
    final back = workoutFromJson(viaText(workoutToJson(w)));
    expect(back.finishedAt, end);
    final s = back.exercises.first.sets.first;
    expect(s.values.extra, 10);
    expect(s.target!.secs, 90);
    expect(s.missed(Measure.bodyweightTimed), isTrue);
    expect(s.side, Side.right);
    expect(back.exercises.first.temporarySwapFrom, const ExerciseId('ex_chins_supinated'));
    expect(back.exercises.first.sets[1].excludeFromRecords, isTrue);
    expect(back.exercises[1].isExtra, isTrue);
    expect(back.exercises[1].measure, Measure.run);
    expect(personalRecords([WorkoutEntry(workout: back)]).length, 1);
  });

  test('historik: pass och vilodag med anteckning', () {
    final rest = historyFromJson(viaText(historyToJson(RestEntry(date: end, sessionId: const SessionId('V'), note: 'walk'))));
    expect(rest, isA<RestEntry>());
    expect((rest as RestEntry).note, 'walk');
    final w = Workout(id: const WorkoutId('w'), sessionId: const SessionId('A'), startedAt: start, finishedAt: end);
    final h = historyFromJson(viaText(historyToJson(WorkoutEntry(workout: w, source: EntrySource.imported))));
    expect(h.source, EntrySource.imported);
  });

  test('program, vikt, anteckning, egen övning, justering, inställningar', () {
    const p = Program(sessions: [
      Session(id: SessionId('A'), name: 'Chest', slots: [
        Slot(id: SlotId('A1'), exerciseId: ExerciseId('ex_bench_press_bb')),
        Slot(id: SlotId('A2'), exerciseId: ExerciseId('ex_chins'), originalExerciseId: ExerciseId('ex_incline_press_smith')),
      ]),
      Session(id: SessionId('V'), name: 'Rest', kind: SessionKind.rest),
    ]);
    final p2 = programFromJson(viaText(programToJson(p)));
    expect(p2.sessions.last.isRest, isTrue);
    expect(p2.sessions.first.slots.last.originalExerciseId, const ExerciseId('ex_incline_press_smith'));

    expect(bodyweightFromJson(viaText(bodyweightToJson(const BodyweightEntry(date: '2026-10-02', kg: 99.8)))).kg, 99.8);

    final n = noteFromJson(viaText(noteToJson(ExerciseNote(
        id: 'n1', exerciseId: const ExerciseId('ex_x'), text: 'seat 4', createdAt: start, pinned: true))));
    expect(n.pinned, isTrue);
    expect(n.isActive, isTrue);

    final c = customExerciseFromJson(viaText(customExerciseToJson(const Exercise(
        id: ExerciseId('custom_1'), name: 'My Hold', group: MuscleGroup.core, measure: Measure.timed, unilateral: true))));
    expect(c.isCustom, isTrue);
    expect(c.unilateral, isTrue);

    final (id, o) = overrideFromJson(viaText(overrideToJson(const ExerciseId('ex_deadlift'), const ExerciseOverride(scheme: SetScheme.ramp))));
    expect(id, const ExerciseId('ex_deadlift'));
    expect(o.scheme, SetScheme.ramp);
    expect(o.measure, isNull);

    final s = settingsFromJson(viaText(settingsToJson(const UserSettings(weightUnit: WeightUnit.lbs, weightGoalKg: 95, ambientEffects: false))));
    expect(s.weightUnit, WeightUnit.lbs);
    expect(s.weightGoalKg, 95);
    expect(s.ambientEffects, isFalse);
  });

  test('okänt enumvärde från framtida version faller tillbaka i stället för att krascha', () {
    final j = workoutToJson(Workout(id: const WorkoutId('w'), sessionId: const SessionId('A'), startedAt: start, exercises: const [
      WorkoutExercise(id: 'r', exerciseId: ExerciseId('x'), measure: Measure.weight),
    ]));
    ((j['exercises'] as List).first as Map)['measure'] = 'teleportation';
    expect(workoutFromJson(viaText(j)).exercises.single.measure, Measure.weight);
  });
}
