import 'package:flutter_test/flutter_test.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/workout_comparator.dart';

void main() {
  group('WorkoutComparator', () {
    late WorkoutSession baseSession;

    setUp(() {
      baseSession = WorkoutSession(
        id: 'session_1',
        routineId: 'routine_1',
        routineNameSnapshot: 'Push A',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now().add(const Duration(minutes: 60)),
        durationSeconds: 3600,
        exercises: [],
      );
    });

    test('calculateSets returns correct number of completed work sets', () {
      final session = WorkoutSession(
        id: 'session_1',
        routineId: 'routine_1',
        routineNameSnapshot: 'Push A',
        startedAt: baseSession.startedAt,
        finishedAt: baseSession.finishedAt,
        durationSeconds: 0,
        exercises: [
          WorkoutExercise(
            exerciseId: 'ex_1',
            exerciseNameSnapshot: 'Bench',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(weight: 60, reps: 10, completed: true, warmup: true), // ignored
              WorkoutSet(weight: 80, reps: 10, completed: true), // +1
              WorkoutSet(weight: 80, reps: 10, completed: false), // ignored
              WorkoutSet(weight: 80, reps: 10, completed: true), // +1
            ],
          )
        ],
      );

      final sets = WorkoutComparator.calculateSets(session);
      expect(sets, 2);
    });

    test('calculateVolume returns correct total volume', () {
      final session = WorkoutSession(
        id: 'session_1',
        routineId: 'routine_1',
        routineNameSnapshot: 'Push A',
        startedAt: baseSession.startedAt,
        finishedAt: baseSession.finishedAt,
        durationSeconds: 0,
        exercises: [
          WorkoutExercise(
            exerciseId: 'ex_1',
            exerciseNameSnapshot: 'Bench',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(weight: 80, reps: 10, completed: true), // 800
              WorkoutSet(weight: 80, reps: 10, completed: true), // 800
              WorkoutSet(weight: 0, reps: 15, completed: true), // 0
            ],
          ),
          WorkoutExercise(
            exerciseId: 'ex_2',
            exerciseNameSnapshot: 'Squat',
            muscleGroupSnapshot: 'Piernas',
            sets: [
              WorkoutSet(weight: 100, reps: 5, completed: true), // 500
              WorkoutSet(weight: 50, reps: 10, completed: false), // ignored
            ],
          )
        ],
      );

      final volume = WorkoutComparator.calculateVolume(session);
      expect(volume, 2100.0);
    });

    test('compare returns null if previous session is null', () {
      final comparison = WorkoutComparator.compare(currentSession: baseSession, previousSession: null);
      expect(comparison, isNull);
    });

    test('compare calculates correct percentages', () {
      final current = WorkoutSession(
        id: 'session_1',
        routineId: 'routine_1',
        routineNameSnapshot: 'Push A',
        startedAt: baseSession.startedAt,
        finishedAt: baseSession.finishedAt,
        durationSeconds: 0,
        exercises: [
          WorkoutExercise(
            exerciseId: 'ex_1',
            exerciseNameSnapshot: 'Bench',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(weight: 100, reps: 10, completed: true), // 1000
            ],
          ),
        ],
      );

      final previous = WorkoutSession(
        id: 'session_0',
        routineId: 'routine_1',
        routineNameSnapshot: 'Push A',
        startedAt: baseSession.startedAt,
        finishedAt: baseSession.finishedAt,
        durationSeconds: 0,
        exercises: [
          WorkoutExercise(
            exerciseId: 'ex_1',
            exerciseNameSnapshot: 'Bench',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(weight: 80, reps: 10, completed: true), // 800
            ],
          ),
        ],
      );

      final comparison = WorkoutComparator.compare(currentSession: current, previousSession: previous);
      
      expect(comparison, isNotNull);
      expect(comparison!.previousVolume, 800.0);
      expect(comparison.volumeDifferencePercent, 25.0); // (1000 - 800) / 800 = 0.25 -> 25%
      expect(comparison.setsDifference, 0);
    });
  });
}
