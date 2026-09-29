import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';
import 'package:core/features/workout/application/workout_history_index.dart';
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
    test(
      'newer routine with fewer set slots does not erase older slot memory',
      () {
        final upperA = WorkoutSession(
          id: 'upper-a-old',
          routineId: 'upper-a',
          routineNameSnapshot: 'Upper A',
          startedAt: DateTime(2026, 9, 7),
          finishedAt: DateTime(2026, 9, 7, 1),
          durationSeconds: 3600,
          exercises: const [
            WorkoutExercise(
              exerciseId: 'press',
              exerciseNameSnapshot: 'Press',
              muscleGroupSnapshot: 'Pecho',
              sets: [
                WorkoutSet(
                  weight: 20,
                  reps: 6,
                  completed: true,
                  setType: WorkoutSetType.warmup,
                ),
                WorkoutSet(
                  weight: 40,
                  reps: 2,
                  completed: true,
                  setType: WorkoutSetType.approach,
                ),
                WorkoutSet(
                  weight: 42.5,
                  reps: 2,
                  completed: true,
                  setType: WorkoutSetType.approach,
                ),
                WorkoutSet(
                  weight: 60,
                  reps: 10,
                  completed: true,
                  setType: WorkoutSetType.working,
                ),
                WorkoutSet(
                  weight: 60,
                  reps: 10,
                  completed: true,
                  setType: WorkoutSetType.working,
                ),
              ],
            ),
          ],
        );

        final upperB = WorkoutSession(
          id: 'upper-b-new',
          routineId: 'upper-b',
          routineNameSnapshot: 'Upper B',
          startedAt: DateTime(2026, 9, 10),
          finishedAt: DateTime(2026, 9, 10, 1),
          durationSeconds: 3600,
          exercises: const [
            WorkoutExercise(
              exerciseId: 'press',
              exerciseNameSnapshot: 'Press',
              muscleGroupSnapshot: 'Pecho',
              sets: [
                WorkoutSet(
                  weight: 45,
                  reps: 2,
                  completed: true,
                  setType: WorkoutSetType.approach,
                ),
                WorkoutSet(
                  weight: 47.5,
                  reps: 2,
                  completed: true,
                  setType: WorkoutSetType.approach,
                ),
                WorkoutSet(
                  weight: 62.5,
                  reps: 8,
                  completed: true,
                  setType: WorkoutSetType.working,
                ),
              ],
            ),
          ],
        );

        final currentUpperA = WorkoutSession(
          id: 'upper-a-current',
          routineId: 'upper-a',
          routineNameSnapshot: 'Upper A',
          startedAt: DateTime(2026, 9, 14),
          finishedAt: DateTime(2026, 9, 14),
          durationSeconds: 0,
          exercises: const [
            WorkoutExercise(
              exerciseId: 'press',
              exerciseNameSnapshot: 'Press',
              muscleGroupSnapshot: 'Pecho',
              sets: [
                WorkoutSet(
                  weight: 0,
                  reps: 0,
                  completed: false,
                  setType: WorkoutSetType.warmup,
                ),
                WorkoutSet(
                  weight: 0,
                  reps: 0,
                  completed: false,
                  setType: WorkoutSetType.approach,
                ),
                WorkoutSet(
                  weight: 0,
                  reps: 0,
                  completed: false,
                  setType: WorkoutSetType.approach,
                ),
                WorkoutSet(
                  weight: 0,
                  reps: 0,
                  completed: false,
                  setType: WorkoutSetType.working,
                ),
                WorkoutSet(
                  weight: 0,
                  reps: 0,
                  completed: false,
                  setType: WorkoutSetType.working,
                ),
              ],
            ),
          ],
        );

        final synthetic =
            ExercisePerformanceMemory.syntheticPreviousSessionForCurrent(
          [upperA, upperB],
          currentUpperA,
        );

        expect(synthetic, isNotNull);
        final sets = synthetic!.exercises.single.sets;
        expect(sets, hasLength(5));

        // Upper B has no warm-up, so warm-up #1 falls back to Upper A.
        expect(sets[0].setType, WorkoutSetType.warmup);
        expect(sets[0].weight, 20);
        expect(sets[0].reps, 6);

        // Upper B has both approach slots, so they are the newest memory.
        expect(sets[1].setType, WorkoutSetType.approach);
        expect(sets[1].weight, 45);
        expect(sets[2].weight, 47.5);

        // Working #1 comes from Upper B, but working #2 falls back to Upper A.
        expect(sets[3].setType, WorkoutSetType.working);
        expect(sets[3].weight, 62.5);
        expect(sets[3].reps, 8);
        expect(sets[4].setType, WorkoutSetType.working);
        expect(sets[4].weight, 60);
        expect(sets[4].reps, 10);
      },
    );

    test('indexed memory uses the same per-slot fallback behavior', () {
      final older = WorkoutSession(
        id: 'older',
        routineId: 'a',
        routineNameSnapshot: 'Upper A',
        startedAt: DateTime(2026, 9, 7),
        finishedAt: DateTime(2026, 9, 7, 1),
        durationSeconds: 3600,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'press',
            exerciseNameSnapshot: 'Press',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(
                weight: 20,
                reps: 6,
                completed: true,
                setType: WorkoutSetType.warmup,
              ),
              WorkoutSet(
                weight: 60,
                reps: 10,
                completed: true,
                setType: WorkoutSetType.working,
              ),
              WorkoutSet(
                weight: 60,
                reps: 9,
                completed: true,
                setType: WorkoutSetType.working,
              ),
            ],
          ),
        ],
      );
      final newer = WorkoutSession(
        id: 'newer',
        routineId: 'b',
        routineNameSnapshot: 'Upper B',
        startedAt: DateTime(2026, 9, 10),
        finishedAt: DateTime(2026, 9, 10, 1),
        durationSeconds: 3600,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'press',
            exerciseNameSnapshot: 'Press',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(
                weight: 62.5,
                reps: 8,
                completed: true,
                setType: WorkoutSetType.working,
              ),
            ],
          ),
        ],
      );
      final current = WorkoutSession(
        id: 'current',
        routineId: 'a',
        routineNameSnapshot: 'Upper A',
        startedAt: DateTime(2026, 9, 14),
        finishedAt: DateTime(2026, 9, 14),
        durationSeconds: 0,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'press',
            exerciseNameSnapshot: 'Press',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(
                weight: 0,
                reps: 0,
                completed: false,
                setType: WorkoutSetType.warmup,
              ),
              WorkoutSet(
                weight: 0,
                reps: 0,
                completed: false,
                setType: WorkoutSetType.working,
              ),
              WorkoutSet(
                weight: 0,
                reps: 0,
                completed: false,
                setType: WorkoutSetType.working,
              ),
            ],
          ),
        ],
      );

      final index = WorkoutHistoryIndex.build([older, newer]);
      final synthetic =
          ExercisePerformanceMemory.syntheticPreviousSessionForCurrentInIndex(
        index,
        current,
      );

      final sets = synthetic!.exercises.single.sets;
      expect(sets[0].weight, 20);
      expect(sets[1].weight, 62.5);
      expect(sets[2].weight, 60);
    });

  });
}
