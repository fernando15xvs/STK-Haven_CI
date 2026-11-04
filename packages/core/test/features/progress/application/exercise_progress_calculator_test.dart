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

    test('30-day e1RM does not compare against a workout 45 days ago', () {
      final now = DateTime.now();
      final sessions = [
        session(id: 'old', startedAt: now.subtract(const Duration(days: 45)),
          sets: const [WorkoutSet(weight: 20, reps: 8, completed: true)]),
        session(id: 'latest', startedAt: now.subtract(const Duration(hours: 1)),
          sets: const [WorkoutSet(weight: 32.5, reps: 8, completed: true)]),
      ];
      final trend = ExerciseProgressCalculator.calculateTrend(sessions, 'bench');
      expect(trend.current1RM, greaterThan(0));
      expect(trend.absoluteChange30Days, isNull);
      expect(trend.percentChange30Days, isNull);
      expect(trend.latestComparison, isNotNull);
    });

    test('30-day e1RM references earliest workout within current window', () {
      final now = DateTime.now();
      final sessions = [
        session(id: 'too-old', startedAt: now.subtract(const Duration(days: 50)),
          sets: const [WorkoutSet(weight: 10, reps: 8, completed: true)]),
        session(id: 'baseline', startedAt: now.subtract(const Duration(days: 25)),
          sets: const [WorkoutSet(weight: 20, reps: 8, completed: true)]),
        session(id: 'recent', startedAt: now.subtract(const Duration(days: 6)),
          sets: const [WorkoutSet(weight: 29, reps: 8, completed: true)]),
        session(id: 'latest', startedAt: now.subtract(const Duration(hours: 1)),
          sets: const [WorkoutSet(weight: 32.5, reps: 8, completed: true)]),
      ];
      final trend = ExerciseProgressCalculator.calculateTrend(sessions, 'bench');
      // At identical reps, e1RM scales linearly with recorded weight;
      // the 25-day baseline is used, never the 50-day history entry.
      final expectedPercent = (32.5 / 20 - 1) * 100;
      expect(trend.percentChange30Days, closeTo(expectedPercent, 0.01));
      expect(trend.absoluteChange30Days, isNotNull);
      expect(trend.sessionCount, 4);
    });

    test('latest estimate and lifetime peak are independent', () {
      final oldPeakDate = DateTime(2026, 10, 7, 16);
      final trend = ExerciseProgressCalculator.calculateTrend([
        session(
          id: 'peak',
          startedAt: oldPeakDate,
          sets: const [WorkoutSet(weight: 60, reps: 8, completed: true)],
        ),
        session(
          id: 'latest',
          startedAt: DateTime(2026, 10, 30, 16),
          sets: const [WorkoutSet(weight: 35, reps: 8, completed: true)],
        ),
      ], 'bench');
      expect(trend.current1RM, greaterThan(0));
      expect(trend.bestRecorded1RM, greaterThan(trend.current1RM));
      expect(trend.bestRecorded1RMAt, oldPeakDate);
      expect(trend.latestSession!.sessionId, 'latest');
      expect(trend.history1RM, hasLength(2));
    });

    test('stale latest workout has no invented 30-day comparison', () {
      final now = DateTime.now();
      final sessions = [
        session(id: 'older', startedAt: now.subtract(const Duration(days: 65)),
          sets: const [WorkoutSet(weight: 20, reps: 8, completed: true)]),
        session(id: 'old', startedAt: now.subtract(const Duration(days: 45)),
          sets: const [WorkoutSet(weight: 32.5, reps: 8, completed: true)]),
      ];
      final trend = ExerciseProgressCalculator.calculateTrend(sessions, 'bench');
      expect(trend.current1RM, greaterThan(0));
      expect(trend.percentChange30Days, isNull);
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
      expect(dashboard.bestRecorded1RM, 0);
      expect(dashboard.bestRecorded1RMAt, isNull);
      expect(dashboard.lastPerformedAt, isNull);
      expect(dashboard.hasRecordedWork, false);
    });
  });
}
