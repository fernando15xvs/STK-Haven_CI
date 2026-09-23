import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/exercise_memory_actions.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutExercise exercise(List<WorkoutSet> sets) => WorkoutExercise(
      exerciseId: 'press-inclinado',
      exerciseNameSnapshot: 'Press Inclinado',
      muscleGroupSnapshot: 'Pecho',
      sets: sets,
    );

WorkoutSet set({
  required double weight,
  required int reps,
  int? rir,
  bool completed = false,
  WorkoutSetType type = WorkoutSetType.working,
  int rest = 120,
}) =>
    WorkoutSet(
      weight: weight,
      reps: reps,
      rir: rir,
      completed: completed,
      setType: type,
      restSeconds: rest,
    );

void main() {
  group('ExerciseMemoryActions.applyPreviousExercise', () {
    test('prefills aligned completed values without completing current work', () {
      final current = exercise([
        set(weight: 0, reps: 0, type: WorkoutSetType.warmup, rest: 45),
        set(weight: 0, reps: 0, rest: 150),
        set(weight: 0, reps: 0, rest: 150),
      ]);
      final previous = exercise([
        set(
          weight: 20,
          reps: 12,
          completed: true,
          type: WorkoutSetType.warmup,
        ),
        set(weight: 50, reps: 10, rir: 1, completed: true),
        set(weight: 50, reps: 9, rir: 1, completed: true),
      ]);

      final result = ExerciseMemoryActions.applyPreviousExercise(
        current: current,
        previousAligned: previous,
      );

      expect(result.sets[0].weight, 20);
      expect(result.sets[1].weight, 50);
      expect(result.sets[1].reps, 10);
      expect(result.sets[1].rir, 1);
      expect(result.sets[2].reps, 9);
      expect(result.sets.every((item) => !item.completed), isTrue);
      expect(result.sets[1].restSeconds, 150);
    });

    test('does not borrow missing or different-type history', () {
      final current = exercise([
        set(weight: 0, reps: 0, type: WorkoutSetType.warmup),
        set(weight: 0, reps: 0),
      ]);
      final previous = exercise([
        set(weight: 45, reps: 8, completed: false, type: WorkoutSetType.warmup),
        set(weight: 55, reps: 8, completed: true, type: WorkoutSetType.approach),
      ]);

      final result = ExerciseMemoryActions.applyPreviousExercise(
        current: current,
        previousAligned: previous,
      );

      expect(result.sets[0].weight, 0);
      expect(result.sets[1].weight, 0);
    });

    test('normalizes detailed unilateral history to limiting side', () {
      final current = exercise([set(weight: 0, reps: 0)]);
      final previous = exercise([
        WorkoutSet(
          weight: 30,
          reps: 10,
          completed: true,
          rir: 2,
          leftCompleted: true,
          rightCompleted: true,
          leftWeight: 30,
          leftReps: 10,
          leftRir: 2,
          rightWeight: 32,
          rightReps: 8,
          rightRir: 1,
        ),
      ]);

      final result = ExerciseMemoryActions.applyPreviousExercise(
        current: current,
        previousAligned: previous,
      );

      expect(result.sets.single.weight, 30);
      expect(result.sets.single.reps, 8);
      expect(result.sets.single.rir, 1);
      expect(result.sets.single.leftCompleted, isFalse);
      expect(result.sets.single.rightCompleted, isFalse);
      expect(result.sets.single.hasDetailedSideData, isFalse);
    });
  });

  group('ExerciseMemoryActions.copyPreviousSet', () {
    test('copies nearest previous set of the same type', () {
      final current = exercise([
        set(weight: 20, reps: 12, type: WorkoutSetType.warmup),
        set(weight: 50, reps: 10, rir: 2),
        set(weight: 25, reps: 5, type: WorkoutSetType.approach),
        set(weight: 0, reps: 0),
      ]);

      final result = ExerciseMemoryActions.copyPreviousSet(
        current: current,
        setIndex: 3,
      );

      expect(result.sets[3].weight, 50);
      expect(result.sets[3].reps, 10);
      expect(result.sets[3].rir, 2);
      expect(result.sets[3].setType, WorkoutSetType.working);
      expect(result.sets[3].completed, isFalse);
    });

    test('returns unchanged when there is no earlier same-type set', () {
      final current = exercise([
        set(weight: 0, reps: 0, type: WorkoutSetType.approach),
        set(weight: 0, reps: 0),
      ]);

      final result = ExerciseMemoryActions.copyPreviousSet(
        current: current,
        setIndex: 0,
      );

      expect(identical(result, current), isTrue);
    });
  });
}
