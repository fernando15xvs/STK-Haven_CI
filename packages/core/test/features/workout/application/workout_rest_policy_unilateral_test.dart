import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/unilateral_set_coordinator.dart';
import 'package:core/features/workout/application/workout_rest_policy.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutExercise unilateral(WorkoutSet set) => WorkoutExercise(
  exerciseId: 'row',
  exerciseNameSnapshot: 'Remo unilateral',
  muscleGroupSnapshot: 'back',
  unilateral: true,
  sets: [set],
);

void main() {
  for (final sidePause in [0, 60]) {
    test('two sides form one set; no final automatic rest with side pause $sidePause', () {
      final first = UnilateralSetCoordinator.toggleSide(
        WorkoutSet(
          weight: 20, reps: 10, completed: false, restSeconds: 120,
          sideRestSeconds: sidePause,
        ),
        WorkoutSide.left,
      );
      expect(first.set.completed, false);
      expect(first.shouldStartInterSideRest, sidePause > 0);
      final second = UnilateralSetCoordinator.toggleSide(
        first.set, WorkoutSide.right,
      );
      expect(second.set.leftCompleted, true);
      expect(second.set.rightCompleted, true);
      expect(second.set.completed, true);
      expect(second.shouldStartInterSideRest, false);
      for (final mode in RestTimingMode.values) {
        final rest = WorkoutRestPolicy.decide(
          mode: mode,
          exercises: [unilateral(second.set)],
          exerciseIndex: 0,
          setIndex: 0,
        );
        expect(rest.shouldStartRest, false, reason: '$mode');
        expect(rest.restSeconds, 0);
      }
    });
  }

  test('a completed unilateral pair still rests when another set is pending', () {
    const completed = WorkoutSet(
      weight: 20, reps: 8, completed: true,
      leftCompleted: true, rightCompleted: true,
      restSeconds: 120, sideRestSeconds: 60,
    );
    final exercise = WorkoutExercise(
      exerciseId: 'row', exerciseNameSnapshot: 'Remo',
      muscleGroupSnapshot: 'back', unilateral: true,
      sets: [completed, const WorkoutSet(
        weight: 20, reps: 8, completed: false,
        restSeconds: 120, sideRestSeconds: 60,
      )],
    );
    final decision = WorkoutRestPolicy.decide(
      mode: RestTimingMode.completedSet,
      exercises: [exercise], exerciseIndex: 0, setIndex: 0,
    );
    expect(decision.shouldStartRest, true);
    expect(decision.restSeconds, 120);
  });

  test('existing bilateral completed-set rest behavior is preserved', () {
    final exercise = WorkoutExercise(
      exerciseId: 'squat', exerciseNameSnapshot: 'Sentadilla',
      muscleGroupSnapshot: 'legs',
      sets: [const WorkoutSet(
        weight: 60, reps: 8, completed: true, restSeconds: 90,
      )],
    );
    final decision = WorkoutRestPolicy.decide(
      mode: RestTimingMode.completedSet,
      exercises: [exercise], exerciseIndex: 0, setIndex: 0,
    );
    expect(decision.shouldStartRest, true);
    expect(decision.restSeconds, 90);
  });
}
