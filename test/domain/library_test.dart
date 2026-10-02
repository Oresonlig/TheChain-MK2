import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';

void main() {
  test('id:n är exakt MK1:s exId (nycklar ur Niklas riktiga state)', () {
    expect(exerciseIdFromName('Bench Press (BB)'), const ExerciseId('ex_bench_press_bb'));
    expect(exerciseIdFromName('Face Pulls (external rotation)'), const ExerciseId('ex_face_pulls_external_rotation'));
    expect(exerciseIdFromName('Pull-ups (pronated)'), const ExerciseId('ex_pull_ups_pronated'));
    expect(exerciseIdFromName('Power Clean + Shoulder Press'), const ExerciseId('ex_power_clean_shoulder_press'));
    expect(exerciseIdFromName('Chins (supinated)'), const ExerciseId('ex_chins_supinated'));
    expect(exerciseIdFromName("  Weird -- Name!! "), const ExerciseId('ex_weird_name'));
  });

  test('biblioteket: inga dubbletter, alla har namn', () {
    final ids = exerciseLibrary.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(exerciseLibrary.length, greaterThan(100));
    expect(exerciseLibrary.every((e) => e.name.isNotEmpty && !e.isCustom), isTrue);
  });

  test('mätsätt följer MK1 för stickprov', () {
    expect(libraryExercise(const ExerciseId('ex_dead_hang'))!.measure, Measure.bodyweightTimed);
    expect(libraryExercise(const ExerciseId('ex_assault_bike'))!.measure, Measure.cardioSprint);
    expect(libraryExercise(const ExerciseId('ex_running_with_sprints'))!.measure, Measure.runSprint);
    expect(libraryExercise(const ExerciseId('ex_ab_wheel'))!.measure, Measure.repsOnly);
    expect(libraryExercise(const ExerciseId('ex_chins_supinated'))!.measure, Measure.bodyweight);
    expect(libraryExercise(const ExerciseId('ex_bench_press_bb'))!.measure, Measure.weight);
  });

  test('resolveExercise: egen övning först, justering applicerad', () {
    const myId = ExerciseId('custom_1');
    const mine = Exercise(id: myId, name: 'My Press', group: MuscleGroup.chest, measure: Measure.weight, isCustom: true);
    expect(resolveExercise(myId, custom: {myId: mine})!.name, 'My Press');
    final dl = resolveExercise(const ExerciseId('ex_deadlift'),
        overrides: {const ExerciseId('ex_deadlift'): const ExerciseOverride(scheme: SetScheme.ramp)})!;
    expect(dl.scheme, SetScheme.ramp);
    expect(resolveExercise(const ExerciseId('ex_finns_inte')), isNull);
  });
}
