import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session({
  required String id,
  required String routineId,
  required String routineName,
  required DateTime date,
  required String exerciseId,
  required double weight,
  required int reps,
  int? rir,
}) {
  return WorkoutSession(
    id: id,
    routineId: routineId,
    routineNameSnapshot: routineName,
    startedAt: date,
    finishedAt: date.add(const Duration(hours: 1)),
    durationSeconds: 3600,
    exercises: [
      WorkoutExercise(
        exerciseId: exerciseId,
        exerciseNameSnapshot: 'Press inclinado',
        muscleGroupSnapshot: 'Pecho',
        sets: [
          WorkoutSet(
            weight: weight,
            reps: reps,
            rir: rir,
            completed: true,
          ),
        ],
      ),
    ],
  );
}

void main() {
  group('ExercisePerformanceMemory', () {
    test('same exerciseId follows latest performance across routines A/B/C', () {
      final monday = _session(
        id: 'monday',
        routineId: 'push-a',
        routineName: 'Push A',
        date: DateTime(2026, 9, 7),
        exerciseId: 'incline-press',
        weight: 50,
        reps: 10,
        rir: 1,
      );
      final wednesday = _session(
        id: 'wednesday',
        routineId: 'push-b',
        routineName: 'Push B',
        date: DateTime(2026, 9, 9),
        exerciseId: 'incline-press',
        weight: 52.5,
        reps: 9,
        rir: 1,
      );
      final friday = _session(
        id: 'friday',
        routineId: 'push-c',
        routineName: 'Push C',
        date: DateTime(2026, 9, 11),
        exerciseId: 'incline-press',
        weight: 52.5,
        reps: 10,
        rir: 1,
      );

      final beforePushC = ExercisePerformanceMemory.latestForExercise(
        [monday, wednesday],
        'incline-press',
      );
      expect(beforePushC, isNotNull);
      expect(beforePushC!.session.id, 'wednesday');
      expect(beforePushC.routineName, 'Push B');
      expect(beforePushC.latestRepresentativeSet!.weight, 52.5);
      expect(beforePushC.latestRepresentativeSet!.reps, 9);

      final afterPushC = ExercisePerformanceMemory.latestForExercise(
        [monday, wednesday, friday],
        'incline-press',
      );
      expect(afterPushC, isNotNull);
      expect(afterPushC!.session.id, 'friday');
      expect(afterPushC.routineName, 'Push C');
      expect(afterPushC.latestRepresentativeSet!.weight, 52.5);
      expect(afterPushC.latestRepresentativeSet!.reps, 10);
    });

    test('same name with a different exerciseId never mixes history', () {
      final machineVariant = _session(
        id: 'machine',
        routineId: 'push-a',
        routineName: 'Push A',
        date: DateTime(2026, 9, 7),
        exerciseId: 'incline-machine',
        weight: 70,
        reps: 10,
      );

      expect(
        ExercisePerformanceMemory.latestForExercise(
          [machineVariant],
          'incline-barbell',
        ),
        isNull,
      );
    });

    test('incomplete working sets do not become exercise memory', () {
      final session = WorkoutSession(
        id: 'draft-like',
        routineId: 'push-a',
        routineNameSnapshot: 'Push A',
        startedAt: DateTime(2026, 9, 7),
        finishedAt: DateTime(2026, 9, 7, 1),
        durationSeconds: 3600,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'incline-press',
            exerciseNameSnapshot: 'Press inclinado',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(weight: 50, reps: 10, completed: false),
            ],
          ),
        ],
      );

      expect(
        ExercisePerformanceMemory.latestForExercise(
          [session],
          'incline-press',
        ),
        isNull,
      );
    });

    test('synthetic session carries latest occurrence for each exercise', () {
      final olderPress = _session(
        id: 'press-old',
        routineId: 'a',
        routineName: 'Push A',
        date: DateTime(2026, 9, 7),
        exerciseId: 'press',
        weight: 50,
        reps: 10,
      );
      final newerPress = _session(
        id: 'press-new',
        routineId: 'b',
        routineName: 'Push B',
        date: DateTime(2026, 9, 9),
        exerciseId: 'press',
        weight: 52.5,
        reps: 9,
      );
      final row = _session(
        id: 'row',
        routineId: 'pull',
        routineName: 'Pull',
        date: DateTime(2026, 9, 8),
        exerciseId: 'row',
        weight: 60,
        reps: 12,
      );

      final synthetic = ExercisePerformanceMemory.syntheticPreviousSession(
        [olderPress, newerPress, row],
        ['press', 'row'],
      );

      expect(synthetic, isNotNull);
      expect(synthetic!.exercises.length, 2);
      expect(
        synthetic.exercises
            .firstWhere((exercise) => exercise.exerciseId == 'press')
            .sets
            .first
            .weight,
        52.5,
      );
      expect(
        synthetic.exercises
            .firstWhere((exercise) => exercise.exerciseId == 'row')
            .sets
            .first
            .weight,
        60,
      );
    });

    test('previous display aligns by set type instead of raw set index', () {
      final previous = WorkoutSession(
        id: 'push-a',
        routineId: 'push-a',
        routineNameSnapshot: 'Push A',
        startedAt: DateTime(2026, 9, 7),
        finishedAt: DateTime(2026, 9, 7, 1),
        durationSeconds: 3600,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'incline-press',
            exerciseNameSnapshot: 'Press inclinado',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(
                weight: 20,
                reps: 12,
                completed: true,
                setType: WorkoutSetType.warmup,
              ),
              WorkoutSet(weight: 50, reps: 10, completed: true),
              WorkoutSet(weight: 50, reps: 9, completed: true),
            ],
          ),
        ],
      );
      final current = WorkoutSession(
        id: 'push-b-current',
        routineId: 'push-b',
        routineNameSnapshot: 'Push B',
        startedAt: DateTime(2026, 9, 9),
        finishedAt: DateTime(2026, 9, 9),
        durationSeconds: 0,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'incline-press',
            exerciseNameSnapshot: 'Press inclinado',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(weight: 0, reps: 0, completed: false),
              WorkoutSet(weight: 0, reps: 0, completed: false),
            ],
          ),
        ],
      );

      final synthetic =
          ExercisePerformanceMemory.syntheticPreviousSessionForCurrent(
        [previous],
        current,
      );

      expect(synthetic, isNotNull);
      final sets = synthetic!.exercises.single.sets;
      expect(sets, hasLength(2));
      expect(sets[0].weight, 50);
      expect(sets[0].reps, 10);
      expect(sets[1].weight, 50);
      expect(sets[1].reps, 9);
    });
  });
}
