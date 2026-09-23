import 'package:flutter_test/flutter_test.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';

void main() {
  group('WorkoutSetType', () {
    test('warmup and approach are excluded from effective work', () {
      const warmup = WorkoutSet(
        weight: 20,
        reps: 10,
        completed: true,
        setType: WorkoutSetType.warmup,
      );
      const approach = WorkoutSet(
        weight: 30,
        reps: 6,
        completed: true,
        setType: WorkoutSetType.approach,
      );
      const working = WorkoutSet(
        weight: 40,
        reps: 8,
        completed: true,
      );

      expect(warmup.warmup, isTrue);
      expect(approach.warmup, isTrue);
      expect(working.warmup, isFalse);
    });

    test('legacy warmup constructor remains compatible', () {
      const set = WorkoutSet(
        weight: 20,
        reps: 10,
        completed: true,
        warmup: true,
      );

      expect(set.setType, WorkoutSetType.warmup);
      expect(set.warmup, isTrue);
    });
  });

  group('Unilateral workout', () {
    test('exercise is complete only after all sets are complete', () {
      const incomplete = WorkoutExercise(
        exerciseId: 'curl',
        exerciseNameSnapshot: 'Curl unilateral',
        muscleGroupSnapshot: 'Bíceps',
        unilateral: true,
        unilateralTarget: UnilateralTarget.arm,
        sets: [
          WorkoutSet(
            weight: 10,
            reps: 10,
            completed: false,
            leftCompleted: true,
            rightCompleted: false,
          ),
        ],
      );
      const complete = WorkoutExercise(
        exerciseId: 'curl',
        exerciseNameSnapshot: 'Curl unilateral',
        muscleGroupSnapshot: 'Bíceps',
        unilateral: true,
        unilateralTarget: UnilateralTarget.arm,
        sets: [
          WorkoutSet(
            weight: 10,
            reps: 10,
            completed: true,
            leftCompleted: true,
            rightCompleted: true,
          ),
        ],
      );

      expect(incomplete.completed, isFalse);
      expect(complete.completed, isTrue);
    });
  });
}
