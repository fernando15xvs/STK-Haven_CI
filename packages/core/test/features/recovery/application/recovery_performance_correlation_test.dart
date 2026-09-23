import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/recovery/application/recovery_performance_correlation.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RecoveryCheckIn recovery(
    int day, {
    required int energy,
    required int sleep,
    required int stress,
    required int soreness,
  }) {
    return RecoveryCheckIn(
      date: DateTime(2026, 9, day),
      energy: energy,
      sleep: sleep,
      stress: stress,
      soreness: soreness,
      updatedAt: DateTime(2026, 9, day, 7),
    );
  }

  WorkoutSession session(
    int day,
    double volume, {
    String routineId = 'routine-a',
    String routineName = 'Upper A',
  }) {
    return WorkoutSession(
      id: '$routineId-$day',
      routineId: routineId,
      routineNameSnapshot: routineName,
      startedAt: DateTime(2026, 9, day, 17),
      finishedAt: DateTime(2026, 9, day, 18),
      durationSeconds: 3600,
      exercises: [
        WorkoutExercise(
          exerciseId: 'exercise-a',
          exerciseNameSnapshot: 'Press',
          muscleGroupSnapshot: 'Pecho',
          sets: [
            WorkoutSet(
              weight: volume,
              reps: 1,
              completed: true,
            ),
            const WorkoutSet(
              weight: 999,
              reps: 1,
              completed: true,
              warmup: true,
            ),
            const WorkoutSet(
              weight: 999,
              reps: 1,
              completed: false,
            ),
          ],
        ),
      ],
    );
  }

  group('RecoveryPerformanceCorrelation', () {
    test('pairs recovery with comparable sessions of the same routine', () {
      final insight = RecoveryPerformanceCorrelation.analyze(
        checkIns: [
          recovery(
            2,
            energy: 4,
            sleep: 4,
            stress: 2,
            soreness: 2,
          ),
          recovery(
            3,
            energy: 3,
            sleep: 3,
            stress: 3,
            soreness: 3,
          ),
        ],
        sessions: [
          session(1, 100),
          session(2, 110),
          session(
            2,
            500,
            routineId: 'routine-b',
            routineName: 'Lower B',
          ),
          session(3, 99),
          session(4, 120),
        ],
      );

      expect(insight.matchedWorkoutDays, 2);
      expect(insight.comparableSessions, 2);
      expect(insight.points.map((point) => point.date.day), [3, 2]);
      expect(insight.points[0].volumeChangePercent, closeTo(-10, 0.001));
      expect(insight.points[1].volumeChangePercent, closeTo(10, 0.001));
      expect(
        insight.points.every(
          (point) => point.completedWorkingSets == 1,
        ),
        true,
      );
    });

    test('calculates a positive association from three comparisons', () {
      final insight = RecoveryPerformanceCorrelation.analyze(
        checkIns: [
          recovery(
            2,
            energy: 2,
            sleep: 2,
            stress: 5,
            soreness: 3,
          ),
          recovery(
            3,
            energy: 3,
            sleep: 3,
            stress: 3,
            soreness: 3,
          ),
          recovery(
            4,
            energy: 4,
            sleep: 4,
            stress: 2,
            soreness: 2,
          ),
        ],
        sessions: [
          session(1, 100),
          session(2, 90),
          session(3, 90),
          session(4, 99),
        ],
      );

      expect(insight.hasEnoughData, true);
      expect(insight.coefficient, closeTo(1, 0.001));
      expect(
        insight.association,
        RecoveryPerformanceAssociation.positive,
      );
      expect(insight.averageVolumeChangePercent, closeTo(0, 0.001));
    });

    test('does not claim an association before the minimum sample', () {
      final insight = RecoveryPerformanceCorrelation.analyze(
        checkIns: [
          recovery(
            2,
            energy: 4,
            sleep: 4,
            stress: 2,
            soreness: 2,
          ),
          recovery(
            3,
            energy: 3,
            sleep: 3,
            stress: 3,
            soreness: 3,
          ),
        ],
        sessions: [
          session(1, 100),
          session(2, 105),
          session(3, 110),
        ],
      );

      expect(insight.hasEnoughData, false);
      expect(insight.missingComparisons, 1);
      expect(insight.coefficient, isNull);
      expect(
        insight.association,
        RecoveryPerformanceAssociation.insufficient,
      );
    });

    test('ignores workouts without a same-day recovery check-in', () {
      final insight = RecoveryPerformanceCorrelation.analyze(
        checkIns: [
          recovery(
            3,
            energy: 4,
            sleep: 4,
            stress: 2,
            soreness: 2,
          ),
        ],
        sessions: [
          session(1, 100),
          session(2, 110),
          session(3, 121),
        ],
      );

      expect(insight.matchedWorkoutDays, 1);
      expect(insight.comparableSessions, 1);
      expect(insight.points.single.date.day, 3);
      expect(
        insight.points.single.volumeChangePercent,
        closeTo(10, 0.001),
      );
    });
  });
}
