import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/unilateral_set_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Unilateral Pro Roadmap 2.0', () {
    test('same-weight mode makes second side inherit first-side load', () {
      const leftDone = WorkoutSet(
        weight: 18,
        reps: 10,
        rir: 2,
        completed: false,
        leftCompleted: true,
        leftWeight: 18,
        leftReps: 10,
        leftRir: 2,
        sideRestSeconds: 45,
      );

      final typedForRight = leftDone.copyWith(weight: 22, reps: 8, rir: 1);
      final result = UnilateralSetCoordinator.toggleSide(
        typedForRight,
        WorkoutSide.right,
        sameWeightForBothSides: true,
      );

      expect(result.set.completed, true);
      expect(result.set.leftWeight, 18);
      expect(result.set.rightWeight, 18);
      expect(result.set.rightReps, 8);
      expect(result.set.rightRir, 1);
      expect(result.shouldStartInterSideRest, false);
    });

    test('independent-weight mode preserves a different second-side load', () {
      const leftDone = WorkoutSet(
        weight: 18,
        reps: 10,
        completed: false,
        leftCompleted: true,
        leftWeight: 18,
        leftReps: 10,
      );
      final result = UnilateralSetCoordinator.toggleSide(
        leftDone.copyWith(weight: 16, reps: 9),
        WorkoutSide.right,
      );

      expect(result.set.leftWeight, 18);
      expect(result.set.rightWeight, 16);
      expect(result.set.rightReps, 9);
      expect(result.set.performanceWeight, 16);
      expect(result.set.performanceReps, 9);
    });

    test('preferred first side is returned only before either side starts', () {
      const empty = WorkoutSet(weight: 0, reps: 0, completed: false);
      expect(
        UnilateralSetCoordinator.recommendedFirstSide(
          preferred: WorkoutSide.right,
          set: empty,
        ),
        WorkoutSide.right,
      );

      final started = empty.copyWith(leftCompleted: true);
      expect(
        UnilateralSetCoordinator.recommendedFirstSide(
          preferred: WorkoutSide.right,
          set: started,
        ),
        isNull,
      );
    });

    test('normalized volume avoids artificial 2x jump while raw volume remains available', () {
      const set = WorkoutSet(
        weight: 20,
        reps: 10,
        completed: true,
        leftCompleted: true,
        rightCompleted: true,
        leftWeight: 20,
        leftReps: 10,
        rightWeight: 20,
        rightReps: 10,
      );

      expect(set.combinedSideVolume, 400);
      expect(set.performedVolume, 200);
    });
  });
}
