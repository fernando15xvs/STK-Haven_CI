import 'dart:convert';

import 'package:core/domain/models/coach_client_progress.dart';
import 'package:core/domain/models/coach_exercise_progress.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/coach/application/coach_progress_snapshot_builder.dart';
import 'package:core/features/coach/data/coach_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      expect(progress.trendBaselineAvailable, isTrue);
      expect(progress.workoutsPrevious7d, 0);
      expect(progress.trainingMinutesPrevious7d, 0);
      expect(progress.completedWorkingSetsPrevious7d, 0);
      expect(progress.volumePrevious7d, 0);
    });

    test('captures the previous seven day comparison window', () {
      final progress = CoachProgressSnapshotBuilder.fromHistory(
        [
          session(
            id: 'current',
            startedAt: now.subtract(const Duration(days: 2)),
            durationSeconds: 3600,
          ),
          session(
            id: 'previous-a',
            startedAt: now.subtract(const Duration(days: 8)),
            durationSeconds: 1800,
          ),
          session(
            id: 'previous-b',
            startedAt: now.subtract(const Duration(days: 13)),
            durationSeconds: 1200,
            sets: const [
              WorkoutSet(
                weight: 50,
                reps: 10,
                completed: true,
                rir: 3,
              ),
            ],
          ),
          session(
            id: 'too-old',
            startedAt: now.subtract(const Duration(days: 15)),
          ),
        ],
        now: now,
      );

      expect(progress.workouts7d, 1);
      expect(progress.workoutsPrevious7d, 2);
      expect(progress.trainingMinutesPrevious7d, 50);
      expect(progress.completedWorkingSetsPrevious7d, 3);
      expect(progress.volumePrevious7d, 2400);
      expect(progress.workoutsTrendDelta7d, -1);
      expect(progress.trainingMinutesTrendDelta7d, 10);
      expect(progress.workingSetsTrendDelta7d, -1);
      expect(progress.volumeTrendDelta7d, -500);

      final payload = progress.snapshotToJson();
      expect(payload['trend_baseline_available'], isTrue);
      expect(payload['workouts_previous_7d'], 2);
      expect(payload['training_minutes_previous_7d'], 50);
      expect(payload['completed_working_sets_previous_7d'], 3);
      expect(payload['volume_previous_7d'], 2400);
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

  test('progress service syncs v2 exercise aggregates atomically', () async {
    late http.Request captured;
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          'null',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final service = CoachProgressService(client);
    final progress = CoachClientProgress(
      workouts7d: 1,
      workouts30d: 4,
      trainingMinutes7d: 60,
      completedWorkingSets7d: 10,
      volume7d: 5000,
      generatedAt: DateTime.utc(2026, 10, 7),
    );
    final exercise = CoachExerciseProgressSummary(
      exerciseId: 'bench',
      exerciseName: 'Press banca',
      muscleGroup: 'Pecho',
      lastPerformedAt: DateTime.utc(2026, 10, 6),
      generatedAt: DateTime.utc(2026, 10, 7),
      sessions30d: 4,
      workingSets30d: 16,
      volume30d: 9000,
      averageRir30d: 2.5,
      sessionsPrevious30d: 3,
      workingSetsPrevious30d: 12,
      volumePrevious30d: 7000,
      bestEstimated1Rm30d: 120,
      bestEstimated1RmPrevious30d: 115,
      bestWeight: 110,
      bestWeightAt: DateTime.utc(2026, 10, 1),
      bestEstimated1Rm: 122,
      bestEstimated1RmAt: DateTime.utc(2026, 10, 2),
      bestSetVolume: 1000,
      bestSetVolumeAt: DateTime.utc(2026, 9, 30),
    );

    await service.syncOwnProgress(
      progress,
      exerciseProgress: [exercise],
    );

    expect(
      captured.url.path,
      '/rest/v1/rpc/stk_sync_own_progress_v2',
    );
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body.keys, {
      'p_progress',
      'p_recent_workouts',
      'p_exercise_progress',
    });
    final rows = body['p_exercise_progress'] as List;
    expect(rows, hasLength(1));
    final row = Map<String, dynamic>.from(rows.single as Map);
    expect(row['exercise_id'], 'bench');
    expect(row['best_estimated_1rm'], 122);
    expect(row.containsKey('notes'), isFalse);
    expect(row.containsKey('sets'), isFalse);
    expect(row.containsKey('exercises'), isFalse);
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
          'trend_baseline_available': true,
          'workouts_previous_7d': 3,
          'training_minutes_previous_7d': 180,
          'completed_working_sets_previous_7d': 40,
          'volume_previous_7d': 12000,
        },
        'adherence': {
          'assignment_id': 'assignment-1',
          'assignment_name': 'Plan fuerza',
          'starts_on': '2026-09-01',
          'ends_on': '2026-10-26',
          'scheduled_sessions_7d': 3,
          'completed_sessions_7d': 4,
          'percent_7d': 100,
          'scheduled_sessions_30d': 13,
          'completed_sessions_30d': 13,
          'percent_30d': 100,
        },
        'workouts_visible': false,
        'recent_workouts': const [],
      });

      expect(progress.available, isTrue);
      expect(progress.workoutsVisible, isFalse);
      expect(progress.clientUserId, 'client-1');
      expect(progress.workouts7d, 4);
      expect(progress.averageRir7d, 2.4);
      expect(progress.trendBaselineAvailable, isTrue);
      expect(progress.workoutsPrevious7d, 3);
      expect(progress.workoutsTrendDelta7d, 1);
      expect(progress.frequencyAdherence?.assignmentName, 'Plan fuerza');
      expect(progress.frequencyAdherence?.scheduledSessions7d, 3);
      expect(progress.frequencyAdherence?.percent7d, 100);
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
