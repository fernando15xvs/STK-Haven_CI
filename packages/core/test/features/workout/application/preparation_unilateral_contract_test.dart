import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/unilateral_set_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unilateral exercise can keep preparation bilateral', () {
    final exercise = WorkoutExercise(
      exerciseId: 'curl',
      exerciseNameSnapshot: 'Curl',
      muscleGroupSnapshot: 'Biceps',
      unilateral: true,
      preparationUnilateral: false,
      sets: const [
        WorkoutSet(
          weight: 10,
          reps: 12,
          completed: false,
          setType: WorkoutSetType.warmup,
        ),
        WorkoutSet(
          weight: 15,
          reps: 10,
          completed: false,
          setType: WorkoutSetType.approach,
        ),
        WorkoutSet(
          weight: 20,
          reps: 8,
          completed: false,
          setType: WorkoutSetType.working,
        ),
      ],
    );

    expect(exercise.usesUnilateralTracking(exercise.sets[0]), isFalse);
    expect(exercise.usesUnilateralTracking(exercise.sets[1]), isFalse);
    expect(exercise.usesUnilateralTracking(exercise.sets[2]), isTrue);
  });

  test('preparation can also be unilateral when exercise requires it', () {
    final exercise = WorkoutExercise(
      exerciseId: 'split-squat',
      exerciseNameSnapshot: 'Split squat',
      muscleGroupSnapshot: 'Legs',
      unilateral: true,
      preparationUnilateral: true,
      sets: const [
        WorkoutSet(
          weight: 0,
          reps: 10,
          completed: false,
          setType: WorkoutSetType.warmup,
        ),
        WorkoutSet(
          weight: 20,
          reps: 8,
          completed: false,
          setType: WorkoutSetType.working,
        ),
      ],
    );

    expect(
      exercise.sets.every(exercise.usesUnilateralTracking),
      isTrue,
    );
  });

  test('routine exercise stores independent preparation rests', () {
    const exercise = RoutineExercise(
      exerciseId: 'press',
      order: 0,
      targetSets: 3,
      targetRepsMin: 6,
      targetRepsMax: 10,
      restSeconds: 180,
      warmupSets: 2,
      approachSets: 2,
      warmupRestSeconds: 45,
      approachRestSeconds: 75,
      unilateral: true,
      preparationUnilateral: false,
      unilateralSideRestSeconds: 0,
      preferredUnilateralStartSide: PreferredWorkoutSide.right,
    );

    expect(exercise.restSeconds, 180);
    expect(exercise.warmupRestSeconds, 45);
    expect(exercise.approachRestSeconds, 75);
    expect(exercise.preparationUnilateral, isFalse);
    expect(exercise.unilateralSideRestSeconds, 0);
    expect(
      exercise.preferredUnilateralStartSide,
      PreferredWorkoutSide.right,
    );
  });

  test('zero side rest means direct change with no inter-side timer', () {
    const set = WorkoutSet(
      weight: 20,
      reps: 10,
      completed: false,
      sideRestSeconds: 0,
    );

    final result = UnilateralSetCoordinator.toggleSide(
      set,
      WorkoutSide.right,
    );

    expect(result.set.rightCompleted, isTrue);
    expect(result.set.completed, isFalse);
    expect(result.shouldStartInterSideRest, isFalse);
  });
}
