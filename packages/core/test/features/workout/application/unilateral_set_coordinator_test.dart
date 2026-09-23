import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/unilateral_set_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnilateralSetCoordinator', () {
    test('first side snapshots current fields and requests inter-side rest', () {
      const current = WorkoutSet(
        weight: 12,
        reps: 10,
        rir: 1,
        completed: false,
        sideRestSeconds: 45,
      );

      final result = UnilateralSetCoordinator.toggleSide(
        current,
        WorkoutSide.left,
      );

      expect(result.set.leftCompleted, true);
      expect(result.set.rightCompleted, false);
      expect(result.set.completed, false);
      expect(result.set.leftWeight, 12);
      expect(result.set.leftReps, 10);
      expect(result.set.leftRir, 1);
      expect(result.shouldStartInterSideRest, true);
    });

    test('second side can snapshot different reps and completes full set', () {
      const afterLeft = WorkoutSet(
        weight: 12,
        reps: 8,
        rir: 0,
        completed: false,
        leftCompleted: true,
        leftWeight: 12,
        leftReps: 10,
        leftRir: 1,
        sideRestSeconds: 45,
      );

      final result = UnilateralSetCoordinator.toggleSide(
        afterLeft,
        WorkoutSide.right,
      );

      expect(result.set.completed, true);
      expect(result.set.leftReps, 10);
      expect(result.set.rightReps, 8);
      expect(result.set.leftRir, 1);
      expect(result.set.rightRir, 0);
      expect(result.shouldStartInterSideRest, false);
    });

    test('unselecting one side clears only its snapshot', () {
      const completed = WorkoutSet(
        weight: 12,
        reps: 8,
        completed: true,
        leftCompleted: true,
        rightCompleted: true,
        leftWeight: 12,
        leftReps: 10,
        rightWeight: 12,
        rightReps: 8,
      );

      final result = UnilateralSetCoordinator.toggleSide(
        completed,
        WorkoutSide.left,
      );

      expect(result.set.completed, false);
      expect(result.set.leftCompleted, false);
      expect(result.set.leftWeight, isNull);
      expect(result.set.leftReps, isNull);
      expect(result.set.rightWeight, 12);
      expect(result.set.rightReps, 8);
      expect(result.shouldStartInterSideRest, false);
    });

    test('zero side rest never starts inter-side timer', () {
      const current = WorkoutSet(
        weight: 10,
        reps: 12,
        completed: false,
        sideRestSeconds: 0,
      );

      final result = UnilateralSetCoordinator.toggleSide(
        current,
        WorkoutSide.right,
      );

      expect(result.set.rightCompleted, true);
      expect(result.shouldStartInterSideRest, false);
    });
  });
}
