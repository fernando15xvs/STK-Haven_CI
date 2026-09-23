import 'package:flutter_test/flutter_test.dart';
import 'package:core/features/workout/application/plateau_detector.dart';
import 'package:core/domain/models/workout_session.dart';

void main() {
  group('PlateauDetector', () {
    final now = DateTime.now();

    WorkoutSession createSession(DateTime date, double weight, int reps, {int? rir}) {
      return WorkoutSession(
        id: date.toString(),
        routineId: 'r1',
        routineNameSnapshot: 'Routine 1',
        startedAt: date,
        finishedAt: date.add(const Duration(hours: 1)),
        durationSeconds: 3600,
        exercises: [
          WorkoutExercise(
            exerciseId: 'ex1',
            exerciseNameSnapshot: 'Bench Press',
            muscleGroupSnapshot: 'Chest',
            sets: [
              WorkoutSet(weight: weight, reps: reps, rir: rir, completed: true),
            ],
          )
        ],
      );
    }

    test('returns false if history has less than 3 sessions', () {
      final history = [
        createSession(now.subtract(const Duration(days: 2)), 100, 10),
        createSession(now.subtract(const Duration(days: 1)), 100, 10),
      ];

      final isPlateau = PlateauDetector.hasPlateaued(
        history: history,
        exerciseId: 'ex1',
        targetRepsMin: 8,
      );

      expect(isPlateau, false);
    });

    test('returns true when 3 consecutive sessions have identical max sets', () {
      final history = [
        createSession(now.subtract(const Duration(days: 3)), 100, 10, rir: 0),
        createSession(now.subtract(const Duration(days: 2)), 100, 10, rir: 0),
        createSession(now.subtract(const Duration(days: 1)), 100, 10, rir: 0),
      ];

      final isPlateau = PlateauDetector.hasPlateaued(
        history: history,
        exerciseId: 'ex1',
        targetRepsMin: 8,
      );

      expect(isPlateau, true);
    });

    test('returns false when there is progress in weight', () {
      final history = [
        createSession(now.subtract(const Duration(days: 3)), 100, 10, rir: 0),
        createSession(now.subtract(const Duration(days: 2)), 100, 10, rir: 0),
        createSession(now.subtract(const Duration(days: 1)), 105, 8, rir: 0), // Weight up!
      ];

      final isPlateau = PlateauDetector.hasPlateaued(
        history: history,
        exerciseId: 'ex1',
        targetRepsMin: 8,
      );

      expect(isPlateau, false);
    });
    
    test('returns false when there is progress in reps', () {
      final history = [
        createSession(now.subtract(const Duration(days: 3)), 100, 10, rir: 0),
        createSession(now.subtract(const Duration(days: 2)), 100, 10, rir: 0),
        createSession(now.subtract(const Duration(days: 1)), 100, 11, rir: 0), // Reps up!
      ];

      final isPlateau = PlateauDetector.hasPlateaued(
        history: history,
        exerciseId: 'ex1',
        targetRepsMin: 8,
      );

      expect(isPlateau, false);
    });
    
    test('returns false when there is progress in RIR', () {
      final history = [
        createSession(now.subtract(const Duration(days: 3)), 100, 10, rir: 0),
        createSession(now.subtract(const Duration(days: 2)), 100, 10, rir: 0),
        createSession(now.subtract(const Duration(days: 1)), 100, 10, rir: 1), // RIR up!
      ];

      final isPlateau = PlateauDetector.hasPlateaued(
        history: history,
        exerciseId: 'ex1',
        targetRepsMin: 8,
      );

      expect(isPlateau, false);
    });

    test('returns true if regression happens', () {
      final history = [
        createSession(now.subtract(const Duration(days: 3)), 100, 10, rir: 0),
        createSession(now.subtract(const Duration(days: 2)), 100, 9, rir: 0), // Regression
        createSession(now.subtract(const Duration(days: 1)), 100, 8, rir: 0), // Regression
      ];

      final isPlateau = PlateauDetector.hasPlateaued(
        history: history,
        exerciseId: 'ex1',
        targetRepsMin: 8,
      );

      expect(isPlateau, true); // No progress in the last 3 sessions
    });
  });
}
