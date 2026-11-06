import 'package:flutter_test/flutter_test.dart';
import 'package:core/domain/models/personal_record.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/pr_detector.dart';

void main() {
  group('PRDetector', () {
    late WorkoutSession baseSession;

    setUp(() {
      baseSession = WorkoutSession(
        id: 'session_1',
        routineId: 'routine_1',
        routineNameSnapshot: 'Push A',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        durationSeconds: 0,
        exercises: [],
      );
    });

    test('Detects Max Weight PR', () {
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
            exerciseNameSnapshot: 'Bench Press',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(weight: 80, reps: 10, completed: true),
              WorkoutSet(weight: 85, reps: 5, completed: true), // New PR
            ],
          )
        ],
      );

      final prs = PRDetector.analyze(
        session: session,
        getBestPreviousValue: (id, type) {
          if (type == PRType.maxWeight) return 80.0;
          return 0.0;
        },
      );

      final maxWeightPRs = prs.where((pr) => pr.type == PRType.maxWeight).toList();
      expect(maxWeightPRs.length, 1);
      expect(maxWeightPRs.first.newValue, 85.0);
    });

    test('Detects Best Set Volume PR', () {
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
            exerciseNameSnapshot: 'Bench Press',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(weight: 80, reps: 10, completed: true), // Vol: 800 (New PR)
              WorkoutSet(weight: 85, reps: 5, completed: true),  // Vol: 425
            ],
          )
        ],
      );

      final prs = PRDetector.analyze(
        session: session,
        getBestPreviousValue: (id, type) {
          if (type == PRType.bestSetVolume) return 700.0;
          return 0.0;
        },
      );

      final volumePRs = prs.where((pr) => pr.type == PRType.bestSetVolume).toList();
      expect(volumePRs.length, 1);
      expect(volumePRs.first.newValue, 800.0);
    });

    test('Detects Estimated 1RM PR only for reps <= 12', () {
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
            exerciseNameSnapshot: 'Bench Press',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(weight: 80, reps: 10, completed: true), // ~ 1RM: 106.6
              WorkoutSet(weight: 60, reps: 15, completed: true), // Ignored for 1RM because reps > 12
            ],
          )
        ],
      );

      final prs = PRDetector.analyze(
        session: session,
        getBestPreviousValue: (id, type) {
          if (type == PRType.estimated1RM) return 100.0;
          return 0.0;
        },
      );

      final rmPRs = prs.where((pr) => pr.type == PRType.estimated1RM).toList();
      expect(rmPRs.length, 1);
      expect(rmPRs.first.newValue, closeTo(106.66, 0.1));
    });

    test('No PRs generated if values do not exceed previous bests', () {
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
            exerciseNameSnapshot: 'Bench Press',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(weight: 80, reps: 10, completed: true),
            ],
          )
        ],
      );

      final prs = PRDetector.analyze(
        session: session,
        getBestPreviousValue: (id, type) {
          return 1000.0; // High previous values
        },
      );

      expect(prs.isEmpty, true);
    });

    test('Does not duplicate PRs on multiple sets exceeding previous best', () {
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
            exerciseNameSnapshot: 'Bench Press',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(weight: 85, reps: 10, completed: true), // > 80
              WorkoutSet(weight: 90, reps: 10, completed: true), // > 80
            ],
          )
        ],
      );

      final prs = PRDetector.analyze(
        session: session,
        getBestPreviousValue: (id, type) {
          if (type == PRType.maxWeight) return 80.0;
          return 1000.0;
        },
      );

      expect(prs.length, 1);
      expect(prs.first.newValue, 90.0); // Should only emit the absolute max of the session
    });

    test('Ignores warmup and incomplete sets', () {
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
            exerciseNameSnapshot: 'Bench Press',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(weight: 200, reps: 10, completed: true, warmup: true), // Warmup
              WorkoutSet(weight: 200, reps: 10, completed: false), // Incomplete
              WorkoutSet(weight: 80, reps: 10, completed: true), // Valid
            ],
          )
        ],
      );

      final prs = PRDetector.analyze(
        session: session,
        getBestPreviousValue: (id, type) {
          return 0.0;
        },
      );

      final maxWeightPRs = prs.where((pr) => pr.type == PRType.maxWeight).toList();
      expect(maxWeightPRs.length, 1);
      expect(maxWeightPRs.first.newValue, 80.0); // Should ignore the 200kg sets
    });
    test('GAM-01: real PR during partial workout is valid, but skipped sets are not',
        () {
      final session = WorkoutSession(
        id: 'partial-with-pr',
        routineNameSnapshot: 'Push',
        startedAt: DateTime(2026, 11, 5, 8),
        finishedAt: DateTime(2026, 11, 5, 8, 40),
        durationSeconds: 2400,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'press',
            exerciseNameSnapshot: 'Press',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(weight: 80, reps: 8, completed: true),
              WorkoutSet(weight: 110, reps: 0,
                  completed: false, recordedOutcome: 'skipped'),
              WorkoutSet(weight: 105, reps: 0,
                  completed: false, recordedOutcome: 'failed'),
              WorkoutSet(weight: 115, reps: 10, completed: false),
            ],
          ),
        ],
      );
      final detected = PRDetector.analyze(
        session: session,
        getBestPreviousValue: (_, type) =>
            type == PRType.maxWeight ? 75.0 : 1000.0,
      );
      expect(detected.where((pr) => pr.type == PRType.maxWeight),
          hasLength(1));
      expect(detected.single.newValue, 80);
      final repeated = PRDetector.analyze(
        session: session,
        getBestPreviousValue: (_, __) => 1000.0,
      );
      expect(repeated, isEmpty);
    });

  });
}
