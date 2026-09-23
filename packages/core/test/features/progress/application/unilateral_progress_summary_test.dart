import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:core/features/progress/application/unilateral_progress_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports latest and historical e1RM/volume records independently per side', () {
    final first = _session(
      id: 'first',
      date: DateTime(2026, 8, 1),
      leftWeight: 20,
      leftReps: 10,
      rightWeight: 18,
      rightReps: 10,
    );
    final second = _session(
      id: 'second',
      date: DateTime(2026, 8, 5),
      leftWeight: 19,
      leftReps: 10,
      rightWeight: 22,
      rightReps: 8,
    );

    final trend = ExerciseProgressCalculator.calculateTrend(
      [second, first],
      'split-squat',
    );
    final summary = UnilateralProgressCalculator.fromTrend(trend);

    expect(summary.hasComparison, isTrue);
    expect(summary.hasHistoricalRecords, isTrue);
    expect(summary.leftVolume, 190);
    expect(summary.rightVolume, 176);
    expect(summary.bestLeftVolume, 200);
    expect(summary.bestRightVolume, 180);
    expect(summary.bestLeftEstimated1RM, isNotNull);
    expect(summary.bestRightEstimated1RM, isNotNull);
    expect(summary.estimated1RmDifferencePercent, isNotNull);
  });
}

WorkoutSession _session({
  required String id,
  required DateTime date,
  required double leftWeight,
  required int leftReps,
  required double rightWeight,
  required int rightReps,
}) {
  return WorkoutSession(
    id: id,
    routineId: 'legs-${id == 'first' ? 'a' : 'b'}',
    routineNameSnapshot: 'Pierna',
    startedAt: date,
    finishedAt: date.add(const Duration(hours: 1)),
    durationSeconds: 3600,
    exercises: [
      WorkoutExercise(
        exerciseId: 'split-squat',
        exerciseNameSnapshot: 'Split squat',
        muscleGroupSnapshot: 'Piernas',
        unilateral: true,
        sets: [
          WorkoutSet(
            weight: leftWeight < rightWeight ? leftWeight : rightWeight,
            reps: leftReps < rightReps ? leftReps : rightReps,
            completed: true,
            leftCompleted: true,
            rightCompleted: true,
            leftWeight: leftWeight,
            leftReps: leftReps,
            rightWeight: rightWeight,
            rightReps: rightReps,
          ),
        ],
      ),
    ],
  );
}
