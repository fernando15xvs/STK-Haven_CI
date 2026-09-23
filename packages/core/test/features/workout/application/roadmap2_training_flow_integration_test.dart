import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/programs/application/program_rotation_coordinator.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart'
    hide ExerciseSessionComparison;
import 'package:core/features/workout/application/exercise_memory_actions.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';
import 'package:core/features/workout/application/exercise_session_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session({
  required String id,
  required String routineId,
  required DateTime date,
  required double weight,
  int reps = 10,
}) {
  return WorkoutSession(
    id: id,
    routineId: routineId,
    routineNameSnapshot: routineId.toUpperCase(),
    startedAt: date,
    finishedAt: date.add(const Duration(hours: 1)),
    durationSeconds: 3600,
    exercises: [
      WorkoutExercise(
        exerciseId: 'incline-press',
        exerciseNameSnapshot: 'Press inclinado',
        muscleGroupSnapshot: 'Pecho',
        sets: [
          WorkoutSet(
            weight: weight,
            reps: reps,
            rir: 2,
            completed: true,
          ),
        ],
      ),
    ],
  );
}

void main() {
  test('program -> memory -> workout -> summary -> progress stays global by exerciseId', () {
    final startedAt = DateTime(2026, 9, 1);
    final program = TrainingProgram(
      id: 'p1',
      name: 'Push rotation',
      routineIds: const ['push-a', 'push-b', 'push-c'],
      createdAt: startedAt,
      startedAt: startedAt,
      durationWeeks: 8,
    );

    final pushA = _session(
      id: 'a1',
      routineId: 'push-a',
      date: DateTime(2026, 9, 1, 18),
      weight: 50,
    );

    final afterA = ProgramRotationCoordinator.reconcile(program, [pushA]);
    expect(afterA.nextRoutineId, 'push-b');
    expect(afterA.completions, hasLength(1));

    final currentStartedAt = DateTime(2026, 9, 3, 18);
    final currentShape = WorkoutSession(
      id: 'b1',
      routineId: 'push-b',
      routineNameSnapshot: 'PUSH-B',
      startedAt: currentStartedAt,
      finishedAt: currentStartedAt,
      durationSeconds: 0,
      exercises: const [
        WorkoutExercise(
          exerciseId: 'incline-press',
          exerciseNameSnapshot: 'Press inclinado',
          muscleGroupSnapshot: 'Pecho',
          sets: [
            WorkoutSet(
              weight: 0,
              reps: 0,
              completed: false,
              restSeconds: 150,
            ),
          ],
        ),
      ],
    );

    final synthetic = ExercisePerformanceMemory
        .syntheticPreviousSessionForCurrent([pushA], currentShape);
    expect(synthetic, isNotNull);
    final previousAligned = synthetic!.exercises.single;
    expect(previousAligned.sets.single.weight, 50);
    expect(previousAligned.sets.single.reps, 10);

    final prefilled = ExerciseMemoryActions.applyPreviousExercise(
      current: currentShape.exercises.single,
      previousAligned: previousAligned,
    );
    expect(prefilled.sets.single.weight, 50);
    expect(prefilled.sets.single.reps, 10);
    expect(prefilled.sets.single.restSeconds, 150);
    expect(prefilled.sets.single.completed, isFalse);

    final pushB = _session(
      id: 'b1',
      routineId: 'push-b',
      date: DateTime(2026, 9, 3, 18),
      weight: 52.5,
    );

    final comparisons = ExerciseSessionComparison.build(
      currentSession: pushB,
      history: [pushA, pushB],
    );
    expect(comparisons, hasLength(1));
    expect(comparisons.single.previousRoutineName, 'PUSH-A');
    expect(comparisons.single.bestWeightDifference, 2.5);

    final trend = ExerciseProgressCalculator.calculateTrend(
      [pushA, pushB],
      'incline-press',
    );
    expect(trend.sessionCount, 2);
    expect(trend.latestSession?.routineId, 'push-b');
    expect(trend.previousSession?.routineId, 'push-a');
    expect(trend.latestComparison?.weightDelta, 2.5);

    final afterB = ProgramRotationCoordinator.reconcile(afterA, [pushA, pushB]);
    expect(afterB.nextRoutineId, 'push-c');
    expect(afterB.completions, hasLength(2));
  });
}
