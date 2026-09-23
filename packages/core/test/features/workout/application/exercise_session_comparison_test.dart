import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/exercise_session_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session({
  required String id,
  required String? routineId,
  required String routineName,
  required DateTime date,
  required WorkoutExercise exercise,
}) {
  return WorkoutSession(
    id: id,
    routineId: routineId,
    routineNameSnapshot: routineName,
    startedAt: date,
    finishedAt: date.add(const Duration(hours: 1)),
    durationSeconds: 3600,
    exercises: [exercise],
  );
}

WorkoutExercise _bilateralExercise(double weight) => WorkoutExercise(
      exerciseId: 'incline-press',
      exerciseNameSnapshot: 'Press inclinado',
      muscleGroupSnapshot: 'Pecho',
      sets: List.generate(
        2,
        (_) => WorkoutSet(
          weight: weight,
          reps: 8,
          completed: true,
        ),
      ),
    );

void main() {
  test('uses newest previous occurrence globally across routines', () {
    final old = _session(
      id: 'old',
      routineId: 'push-a',
      routineName: 'Push A',
      date: DateTime(2026, 9, 1),
      exercise: _bilateralExercise(40),
    );
    final previous = _session(
      id: 'previous',
      routineId: 'push-b',
      routineName: 'Push B',
      date: DateTime(2026, 9, 5),
      exercise: _bilateralExercise(50),
    );
    final current = _session(
      id: 'current',
      routineId: null,
      routineName: 'Entrenamiento libre',
      date: DateTime(2026, 9, 7),
      exercise: _bilateralExercise(55),
    );

    final result = ExerciseSessionComparison.build(
      currentSession: current,
      history: [old, current, previous],
    );

    expect(result, hasLength(1));
    final comparison = result.single;
    expect(comparison.exerciseId, 'incline-press');
    expect(comparison.previousRoutineName, 'Push B');
    expect(comparison.previousPerformedAt, DateTime(2026, 9, 5));
    expect(comparison.currentVolume, 880);
    expect(comparison.previousVolume, 800);
    expect(comparison.volumeDifferencePercent, closeTo(10, 0.001));
    expect(comparison.bestWeightDifference, 5);
    expect(comparison.workingSetsDifference, 0);
  });

  test('keeps unilateral detailed volume comparable with legacy history', () {
    final previous = _session(
      id: 'legacy',
      routineId: 'legs-a',
      routineName: 'Pierna A',
      date: DateTime(2026, 9, 3),
      exercise: WorkoutExercise(
        exerciseId: 'split-squat',
        exerciseNameSnapshot: 'Split squat',
        muscleGroupSnapshot: 'Piernas',
        unilateral: true,
        sets: const [
          WorkoutSet(weight: 18, reps: 10, completed: true),
        ],
      ),
    );
    final current = _session(
      id: 'detailed',
      routineId: 'legs-b',
      routineName: 'Pierna B',
      date: DateTime(2026, 9, 7),
      exercise: WorkoutExercise(
        exerciseId: 'split-squat',
        exerciseNameSnapshot: 'Split squat',
        muscleGroupSnapshot: 'Piernas',
        unilateral: true,
        sets: const [
          WorkoutSet(
            weight: 20,
            reps: 8,
            completed: true,
            leftCompleted: true,
            rightCompleted: true,
            leftWeight: 20,
            leftReps: 10,
            rightWeight: 22,
            rightReps: 8,
          ),
        ],
      ),
    );

    final result = ExerciseSessionComparison.build(
      currentSession: current,
      history: [previous],
    );

    expect(result, hasLength(1));
    final comparison = result.single;
    // (20*10 + 22*8) / 2 = 188, not the raw combined 376.
    expect(comparison.currentVolume, 188);
    expect(comparison.previousVolume, 180);
    // Progression comparison remains conservative for asymmetric sides.
    expect(comparison.currentBestWeight, 20);
    expect(comparison.previousBestWeight, 18);
  });
}
