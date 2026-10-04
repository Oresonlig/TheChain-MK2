// Utkast-tester för mk1_codec mot en syntetisk MK1-state, formad efter Niklas
// riktiga Copy draft state (permanentSwaps, added-övningar, tagg/mätsätts-
// justeringar). Ersätts/kompletteras med en anonymiserad riktig backup.
import 'package:flutter_test/flutter_test.dart';
import 'package:the_chain/domain/domain.dart';
import 'package:the_chain/mk1/mk1_codec.dart';
import 'package:the_chain/mk1/mk1_legacy.dart';

final t1 = DateTime(2026, 9, 20, 18).millisecondsSinceEpoch;
final t2 = DateTime(2026, 9, 22, 18).millisecondsSinceEpoch;
final t3 = DateTime(2026, 9, 23, 18).millisecondsSinceEpoch;

Map<String, Object?> sample() => {
      'sessionOrder': ['A', 'B', 'K'],
      'restSlots': [2],
      'sessionNameOverrides': {'K': 'Core'},
      'permanentSwaps': {'A2': 'Bench Press (BB)', 'B3': 'Incline Bench Cable Pullover', 'added_K_1': 'Running with Sprints'},
      'exerciseOverrides': {},
      'removedExercises': {'A': ['A4']},
      'addedExercises': {
        'K': [
          {'id': 'added_K_1', 'name': 'Running'},
          {'id': 'added_K_2', 'name': 'My Hold'},
        ],
      },
      'exerciseOrder': {'A': ['A3', 'A1', 'A2']},
      'customExercises': [
        {'id': 'custom_99', 'name': 'My Hold', 'timed': true, 'cat': 'Core'},
      ],
      'exerciseTagOverrides': {
        'ex_deadlift': {'ramp': false},
        'ex_internal_rotator_cuff': {'uni': true},
        'extra_A_5': {'ramp': true},
      },
      'exerciseMeasureOverride': {'ex_running': 'cardio'},
      'exerciseNotes': {'ex_bench_press_bb': 'seat 4'},
      'ignoredPRs': ['Lat Prayers'],
      'unit': 'kg',
      'tempUnit': 'c',
      'timerEnabled': true,
      'timerDefault': 90,
      'weightGoalEnabled': true,
      'weightGoal': 95,
      'weightLog': [
        {'date': '2026-09-20', 'weight': 100.3, 'ts': t1},
        {'date': 'bad'},
      ],
      'log': [
        {
          'passId': 'A',
          'passName': 'Chest + Tri',
          'timestamp': t1,
          'duration': 3600000,
          'exercises': [
            {
              'id': 'A1',
              'name': 'Bench Press (BB)',
              'exId': 'ex_bench_press_bb',
              'measure': 'weight',
              'sets': [
                {'sid': 'wu0', 'warmup': true, 'weight': 60, 'reps': 8},
                {'sid': 'wk0', 'warmup': false, 'weight': 110, 'reps': 4, 'forced': 1},
                {'sid': 'wk1', 'warmup': false, 'weight': 120, 'reps': 2, 'fail': true},
              ],
            },
            {'id': 'A3', 'name': 'Flyes (Cable)', 'skipped': true},
            {
              'id': 'extra_A_5',
              'name': 'Dead Hang',
              'sets': [
                {'warmup': false, 'extra': 10, 'secs': 60, 'bwSnap': 100.3},
              ],
            },
          ],
        },
        {
          'passId': 'B',
          'timestamp': t2,
          'exercises': [
            {
              'id': 'B3',
              'name': 'Unilateral Cable Row', // gammalt namn utan exId → alias + slug
              'sets': [
                {'warmup': false, 'weight': 40, 'reps': 10, 'side': 'L'},
              ],
            },
          ],
        },
        {'timestamp': t3}, // trasig post
      ],
      'cycles': [
        {
          'id': t1 - 1000,
          'done': {
            'A': {'timestamp': t1},
            'V': {'timestamp': t1 + 86400000, 'rest': true, 'exercises': []},
          },
        },
        {
          'id': t2 - 1000,
          'done': {'B': {'timestamp': t2}, 'A': null},
        },
      ],
    };

void main() {
  late Mk1Snapshot snap;
  setUp(() => snap = decodeMk1(sample()));

  group('programmet', () {
    test('passordning, vilodag på position 2 och namnbyte', () {
      expect(snap.program.sessions.map((s) => s.id.value), ['A', 'B', 'V', 'K']);
      expect(snap.program.sessionById(const SessionId('V'))!.isRest, isTrue);
      expect(snap.program.sessionById(const SessionId('K'))!.name, 'Core');
    });

    test('borttagen plats, egen ordning och permanent byte (nya övningen gäller)', () {
      final a = snap.program.sessionById(const SessionId('A'))!;
      expect(a.slots.map((s) => s.id.value), ['A3', 'A1', 'A2']);
      expect(a.slots.last.exerciseId, const ExerciseId('ex_bench_press_bb'));
    });

    test('tillagda övningar, byte på tillagd plats och egen övning via namn', () {
      final k = snap.program.sessionById(const SessionId('K'))!;
      final ids = {for (final s in k.slots) s.id.value: s};
      expect(ids['added_K_1']!.exerciseId, const ExerciseId('ex_running_with_sprints'));
      expect(ids['added_K_2']!.exerciseId, const ExerciseId('custom_99'));
      expect(ids['K1']!.exerciseId, const ExerciseId('ex_ab_wheel'));
    });

    test('MK1:s alias: basplatsen "Pull-ups" blir Pull-ups (pronated)', () {
      expect(legacyCanonicalName('Pull-ups'), 'Pull-ups (pronated)');
      expect(legacyCanonicalName('Unilateral Cable Row'), 'Unilateral Row (Cable)');
    });
  });

  group('historik', () {
    test('pass med start från duration, rader, set och status', () {
      final w = (snap.history.whereType<WorkoutEntry>().firstWhere((e) => e.workout.sessionId.value == 'A')).workout;
      expect(w.finishedAt!.millisecondsSinceEpoch, t1);
      expect(w.startedAt, w.finishedAt!.subtract(const Duration(hours: 1)));
      final bench = w.exercises.first;
      expect(bench.exerciseId, const ExerciseId('ex_bench_press_bb'));
      expect(bench.sets.map((s) => s.kind), [SetKind.warmup, SetKind.work, SetKind.work]);
      expect(bench.sets[1].values.forcedReps, 1);
      expect(w.exercises[1].status, ExerciseStatus.skipped);
    });

    test('MK1-fail räknas inte i PR ("lagt kort ligger")', () {
      final prs = personalRecords(snap.history);
      expect(prs[const ExerciseId('ex_bench_press_bb')]!.value, 110);
    });

    test('extra utan plats, kroppsvikt och mätsätt från biblioteket', () {
      final w = (snap.history.whereType<WorkoutEntry>().first).workout;
      final hang = w.exercises.last;
      expect(hang.isExtra, isTrue);
      expect(hang.exerciseId, const ExerciseId('ex_dead_hang'));
      expect(hang.measure, Measure.bodyweightTimed);
      expect(hang.sets.single.bodyweightKg, 100.3);
    });

    test('gammalt namn utan exId löses via alias; sida L', () {
      final b = snap.history.whereType<WorkoutEntry>().firstWhere((e) => e.workout.sessionId.value == 'B').workout;
      expect(b.exercises.single.exerciseId, const ExerciseId('ex_unilateral_row_cable'));
      expect(b.exercises.single.sets.single.side, Side.left);
    });

    test('vilodag hämtas ur cycles; trasiga poster varnar i stället för att försvinna tyst', () {
      expect(snap.history.whereType<RestEntry>().single.sessionId, const SessionId('V'));
      expect(snap.warnings.any((w) => w.contains('log[2]')), isTrue);
    });
  });

  group('justeringar, anteckningar, vikt, inställningar', () {
    test('platsflaggor ramp/uni + användarens taggar och mätsätt', () {
      final o = snap.overrides;
      expect(o[const ExerciseId('ex_deadlift')]!.scheme, SetScheme.standard); // tagg ramp:false vinner
      expect(o[const ExerciseId('ex_bench_press_bb')]!.scheme, SetScheme.ramp); // A1-plats
      expect(o.containsKey(const ExerciseId('ex_incline_bench_cable_pullover')), isFalse); // inswappad ärver inte B3:s uni
      expect(o[const ExerciseId('ex_internal_rotator_cuff')]!.unilateral, isTrue);
      expect(o[const ExerciseId('ex_running')]!.measure, Measure.cardio);
      expect(o.keys.any((k) => k.value.startsWith('extra_')), isFalse);
    });

    test('anteckningar blir nålade, dolda PR per id, egen övning', () {
      expect(snap.notes.single.pinned, isTrue);
      expect(snap.notes.single.text, 'seat 4');
      expect(snap.hiddenRecords, {const ExerciseId('ex_lat_prayers')});
      expect(snap.custom[const ExerciseId('custom_99')]!.measure, Measure.timed);
    });

    test('kroppsvikt (trasig rad hoppas över) och inställningar', () {
      expect(snap.bodyweight.single.kg, 100.3);
      expect(snap.settings.restTimerSecs, 90);
      expect(snap.settings.weightGoalKg, 95);
    });

    test('runda: MK1 visar 2, MK2:s härledda räknare kalibreras till samma', () {
      expect(snap.mk1Round, 2);
      final offset = snap.roundOffsetFor(snap.program);
      final st = chainState(snap.program, snap.history, manualRestarts: snap.manualRestarts, roundOffset: offset);
      expect(st.round, 2);
    });
  });

  test('tom state ger standardprogram och inga krascher', () {
    final s = decodeMk1(const {});
    expect(s.program.sessions.map((x) => x.id.value), ['A', 'B', 'C', 'D', 'E', 'F', 'V']);
    expect(s.history, isEmpty);
    expect(s.mk1Round, 1);
  });
}
