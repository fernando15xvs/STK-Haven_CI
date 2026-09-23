import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WorkoutSession session({
    required String id,
    required DateTime startedAt,
    required List<WorkoutSet> sets,
  }) {
    return WorkoutSession(
      id: id,
      routineId: 'routine-1',
      routineNameSnapshot: 'Rutina',
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(minutes: 45)),
      durationSeconds: 2700,
      exercises: [
        WorkoutExercise(
          exerciseId: 'bench',
          exerciseNameSnapshot: 'Press banca',
          muscleGroupSnapshot: 'Pecho',
          sets: sets,
        ),
      ],
    );
  }

  group('ExerciseProgressCalculator dashboard metrics', () {
    test('counts only completed working sets', () {
      final history = [
        session(
          id: 'first',
          startedAt: DateTime(2026, 8, 1, 18),
          sets: const [
            WorkoutSet(
              weight: 20,
              reps: 10,
              completed: true,
              setType: WorkoutSetType.warmup,
            ),
            WorkoutSet(
              weight: 40,
              reps: 5,
              completed: true,
              setType: WorkoutSetType.approach,
            ),
            WorkoutSet(weight: 60, reps: 8, completed: true),
            WorkoutSet(weight: 65, reps: 6, completed: false),
          ],
        ),
        session(
          id: 'second',
          startedAt: DateTime(2026, 9, 1, 18),
          sets: const [
            WorkoutSet(weight: 62.5, reps: 8, completed: true),
            WorkoutSet(weight: 65, reps: 6, completed: true),
          ],
        ),
      ];

      final dashboard = ExerciseProgressCalculator.calculateTrend(
        history,
        'bench',
      );

      expect(dashboard.sessionCount, 2);
      expect(dashboard.completedWorkSets, 3);
      expect(dashboard.totalVolume, 1370);
      expect(dashboard.maxWeight, 65);
      expect(dashboard.bestSetVolume, 500);
      expect(dashboard.lastSessionVolume, 890);
      expect(dashboard.lastPerformedAt, DateTime(2026, 9, 1, 18));
      expect(dashboard.current1RM, greaterThan(0));
      expect(dashboard.history1RM, hasLength(2));
      expect(dashboard.hasRecordedWork, true);
    });

    test('ignores sessions without completed working sets', () {
      final dashboard = ExerciseProgressCalculator.calculateTrend(
        [
          session(
            id: 'only-prep',
            startedAt: DateTime(2026, 9, 1),
            sets: const [
              WorkoutSet(
                weight: 20,
                reps: 10,
                completed: true,
                setType: WorkoutSetType.warmup,
              ),
              WorkoutSet(weight: 60, reps: 8, completed: false),
            ],
          ),
        ],
        'bench',
      );

      expect(dashboard.sessionCount, 0);
      expect(dashboard.completedWorkSets, 0);
      expect(dashboard.totalVolume, 0);
      expect(dashboard.current1RM, 0);
      expect(dashboard.lastPerformedAt, isNull);
      expect(dashboard.hasRecordedWork, false);
    });
  });
}
