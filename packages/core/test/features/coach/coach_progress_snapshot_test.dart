import 'package:core/domain/models/coach_client_progress.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/coach/application/coach_progress_snapshot_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoachProgressSnapshotBuilder', () {
    final now = DateTime(2026, 9, 24, 12);

    WorkoutSession session({
      required String id,
      required DateTime startedAt,
      String routine = 'Upper',
      int durationSeconds = 3600,
      List<WorkoutSet>? sets,
    }) {
      return WorkoutSession(
        id: id,
        routineNameSnapshot: routine,
        startedAt: startedAt,
        finishedAt: startedAt.add(Duration(seconds: durationSeconds)),
        durationSeconds: durationSeconds,
        exercises: [
          WorkoutExercise(
            exerciseId: 'exercise-$id',
            exerciseNameSnapshot: 'Private exercise name',
            muscleGroupSnapshot: 'Chest',
            notes: 'Private note',
            sets: sets ??
                const [
                  WorkoutSet(
                    weight: 100,
                    reps: 10,
                    completed: true,
                    rir: 2,
                  ),
                  WorkoutSet(
                    weight: 90,
                    reps: 10,
                    completed: true,
                    rir: 3,
                  ),
                ],
          ),
        ],
        notes: 'Private session note',
      );
    }

    test('aggregates seven and thirty day metrics', () {
      final progress = CoachProgressSnapshotBuilder.fromHistory(
        [
          session(
            id: 'recent-1',
            startedAt: now.subtract(const Duration(days: 1)),
          ),
          session(
            id: 'recent-2',
            startedAt: now.subtract(const Duration(days: 5)),
            durationSeconds: 1800,
          ),
          session(
            id: 'month',
            startedAt: now.subtract(const Duration(days: 20)),
          ),
          session(
            id: 'old',
            startedAt: now.subtract(const Duration(days: 45)),
          ),
        ],
        now: now,
      );

      expect(progress.workouts7d, 2);
      expect(progress.workouts30d, 3);
      expect(progress.trainingMinutes7d, 90);
      expect(progress.completedWorkingSets7d, 4);
      expect(progress.volume7d, 3800);
      expect(progress.averageRir7d, 2.5);
      expect(progress.lastWorkoutAt, now.subtract(const Duration(days: 1)));
    });

    test('shared workout payload excludes notes and exercise details', () {
      final progress = CoachProgressSnapshotBuilder.fromHistory(
        [
          session(
            id: 'private',
            startedAt: now.subtract(const Duration(days: 1)),
          ),
        ],
        now: now,
      );

      final payload = progress.recentWorkoutsToJson().single;

      expect(payload.keys, {
        'workout_id',
        'started_at',
        'routine_name',
        'duration_seconds',
        'planned_working_sets',
        'completed_working_sets',
        'completion_percent',
        'volume',
        'average_rir',
      });
      expect(payload.toString(), isNot(contains('Private note')));
      expect(payload.toString(), isNot(contains('Private exercise name')));
      expect(progress.snapshotToJson().toString(), isNot(contains('Private')));
    });

    test('ignores incomplete and non-working sets in aggregates', () {
      final progress = CoachProgressSnapshotBuilder.fromHistory(
        [
          session(
            id: 'mixed',
            startedAt: now.subtract(const Duration(days: 1)),
            sets: const [
              WorkoutSet(
                weight: 40,
                reps: 10,
                completed: true,
                setType: WorkoutSetType.warmup,
              ),
              WorkoutSet(
                weight: 100,
                reps: 10,
                completed: false,
                rir: 1,
              ),
              WorkoutSet(
                weight: 80,
                reps: 8,
                completed: true,
                rir: 2,
              ),
            ],
          ),
        ],
        now: now,
      );

      expect(progress.completedWorkingSets7d, 1);
      expect(progress.volume7d, 640);
      expect(progress.averageRir7d, 2);
    });

    test('limits recent workout payload without affecting aggregates', () {
      final sessions = [
        for (var i = 0; i < 35; i++)
          session(
            id: 'w$i',
            startedAt: now.subtract(Duration(hours: i * 12)),
          ),
      ];

      final progress = CoachProgressSnapshotBuilder.fromHistory(
        sessions,
        now: now,
        recentWorkoutLimit: 100,
      );

      expect(progress.recentWorkouts, hasLength(30));
      expect(progress.workouts30d, 35);
    });
  });

  group('CoachClientProgress RPC parsing', () {
    test('parses permission-scoped progress and workout visibility', () {
      final progress = CoachClientProgress.fromRpcJson({
        'progress': {
          'available': true,
          'client_user_id': 'client-1',
          'workouts_7d': 4,
          'workouts_30d': 13,
          'training_minutes_7d': 240,
          'completed_working_sets_7d': 55,
          'volume_7d': 14000.5,
          'average_rir_7d': 2.4,
          'last_workout_at': '2026-09-23T10:00:00Z',
          'generated_at': '2026-09-24T10:00:00Z',
        },
        'workouts_visible': false,
        'recent_workouts': const [],
      });

      expect(progress.available, isTrue);
      expect(progress.workoutsVisible, isFalse);
      expect(progress.clientUserId, 'client-1');
      expect(progress.workouts7d, 4);
      expect(progress.averageRir7d, 2.4);
      expect(progress.recentWorkouts, isEmpty);
    });

    test('parses unavailable snapshot without inventing workout access', () {
      final progress = CoachClientProgress.fromRpcJson({
        'progress': {
          'available': false,
          'client_user_id': 'client-2',
        },
        'workouts_visible': false,
        'recent_workouts': const [],
      });

      expect(progress.available, isFalse);
      expect(progress.workoutsVisible, isFalse);
      expect(progress.workouts7d, 0);
      expect(progress.recentWorkouts, isEmpty);
    });
  });
}
