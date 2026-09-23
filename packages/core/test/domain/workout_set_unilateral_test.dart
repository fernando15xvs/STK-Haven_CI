import 'package:core/domain/models/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkoutSet unilateral performance', () {
    test('legacy set falls back to shared weight reps and RIR', () {
      const set = WorkoutSet(
        weight: 12,
        reps: 10,
        rir: 2,
        completed: true,
        leftCompleted: true,
        rightCompleted: true,
      );

      expect(set.weightForSide(WorkoutSide.left), 12);
      expect(set.weightForSide(WorkoutSide.right), 12);
      expect(set.repsForSide(WorkoutSide.left), 10);
      expect(set.repsForSide(WorkoutSide.right), 10);
      expect(set.rirForSide(WorkoutSide.left), 2);
      expect(set.rirForSide(WorkoutSide.right), 2);
      expect(set.performedVolume, 120);
      expect(set.performanceWeight, 12);
      expect(set.performanceReps, 10);
    });

    test('detailed set preserves different reps and RIR by side', () {
      const set = WorkoutSet(
        weight: 12,
        reps: 8,
        rir: 0,
        completed: true,
        leftCompleted: true,
        rightCompleted: true,
        leftWeight: 12,
        leftReps: 10,
        leftRir: 1,
        rightWeight: 12,
        rightReps: 8,
        rightRir: 0,
        sideRestSeconds: 45,
      );

      expect(set.repsForSide(WorkoutSide.left), 10);
      expect(set.repsForSide(WorkoutSide.right), 8);
      expect(set.rirForSide(WorkoutSide.left), 1);
      expect(set.rirForSide(WorkoutSide.right), 0);
      expect(set.sideRestSeconds, 45);
      expect(set.performanceWeight, 12);
      expect(set.performanceReps, 8);
      expect(set.performanceRir, 0);
      expect(set.combinedSideVolume, 216);
      expect(set.performedVolume, 108);
    });

    test('missing RIR on one detailed side is not hidden by the other', () {
      const set = WorkoutSet(
        weight: 12,
        reps: 8,
        rir: 1,
        completed: true,
        leftCompleted: true,
        rightCompleted: true,
        leftWeight: 12,
        leftReps: 10,
        leftRir: 1,
        rightWeight: 12,
        rightReps: 8,
      );

      expect(set.rirForSide(WorkoutSide.left), 1);
      expect(set.rirForSide(WorkoutSide.right), isNull);
      expect(set.performanceRir, isNull);
    });

    test('limiting side is conservative when loads differ', () {
      const set = WorkoutSet(
        weight: 14,
        reps: 9,
        completed: true,
        leftCompleted: true,
        rightCompleted: true,
        leftWeight: 14,
        leftReps: 9,
        rightWeight: 12,
        rightReps: 10,
      );

      expect(set.performanceWeight, 12);
      expect(set.performanceReps, 9);
      expect(set.maxPerformedWeight, 14);
      expect(set.combinedSideVolume, 246);
      expect(set.performedVolume, 123);
    });

    test('copyWith can clear one side without affecting the other', () {
      const original = WorkoutSet(
        weight: 10,
        reps: 10,
        completed: true,
        leftCompleted: true,
        rightCompleted: true,
        leftWeight: 10,
        leftReps: 11,
        rightWeight: 10,
        rightReps: 9,
      );

      final updated = original.copyWith(
        leftCompleted: false,
        completed: false,
        clearLeftPerformance: true,
      );

      expect(updated.leftWeight, isNull);
      expect(updated.leftReps, isNull);
      expect(updated.rightWeight, 10);
      expect(updated.rightReps, 9);
    });
  });
}
