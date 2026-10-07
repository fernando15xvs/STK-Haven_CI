import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/coach/application/coach_exercise_progress_snapshot_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoachExerciseProgressSnapshotBuilder', () {
    final now = DateTime(2026, 10, 7, 12);

    WorkoutSession session({
      required String id,
      required int daysAgo,
      required List<WorkoutSet> sets,
      String exerciseId = 'bench',
      String exerciseName = 'Press banca',
      String muscle = 'Pecho',
    }) {
      final startedAt = now.subtract(Duration(days: daysAgo));
      return WorkoutSession(
        id: id,
        routineNameSnapshot: 'Upper',
        startedAt: startedAt,
        finishedAt: startedAt.add(const Duration(hours: 1)),
        durationSeconds: 3600,
        notes: 'Private session note',
        exercises: [
          WorkoutExercise(
            exerciseId: exerciseId,
            exerciseNameSnapshot: exerciseName,
            muscleGroupSnapshot: muscle,
            notes: 'Private exercise note',
            sets: sets,
          ),
        ],
      );
    }

    test('builds 30-day trends and lifetime PR context', () {
      final rows = CoachExerciseProgressSnapshotBuilder.fromHistory(
        [
          session(
            id: 'current-1',
            daysAgo: 1,
            sets: const [
              WorkoutSet(
                weight: 100,
                reps: 5,
                completed: true,
                rir: 2,
              ),
              WorkoutSet(
                weight: 90,
                reps: 8,
                completed: true,
                rir: 3,
              ),
            ],
          ),
          session(
            id: 'current-2',
            daysAgo: 10,
            sets: const [
              WorkoutSet(
                weight: 95,
                reps: 6,
                completed: true,
                rir: 2,
              ),
            ],
          ),
          session(
            id: 'previous',
            daysAgo: 35,
            sets: const [
              WorkoutSet(
                weight: 90,
                reps: 5,
                completed: true,
                rir: 4,
              ),
            ],
          ),
          session(
            id: 'old-pr',
            daysAgo: 90,
            sets: const [
              WorkoutSet(
                weight: 110,
                reps: 1,
                completed: true,
                rir: 1,
              ),
            ],
          ),
        ],
        now: now,
      );

      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.exerciseId, 'bench');
      expect(row.exerciseName, 'Press banca');
      expect(row.sessions30d, 2);
      expect(row.workingSets30d, 3);
      expect(row.volume30d, 1790);
      expect(row.averageRir30d, closeTo(7 / 3, 0.0001));
      expect(row.sessionsPrevious30d, 1);
      expect(row.workingSetsPrevious30d, 1);
      expect(row.volumePrevious30d, 450);
      expect(row.bestEstimated1Rm30d, closeTo(112.51, 0.02));
      expect(
        row.bestEstimated1RmPrevious30d,
        closeTo(101.26, 0.02),
      );
      expect(row.estimated1RmDelta30d, closeTo(11.25, 0.03));
      expect(row.bestWeight, 110);
      expect(row.bestWeightAt, now.subtract(const Duration(days: 90)).add(
        const Duration(hours: 1),
      ));
      expect(row.bestEstimated1Rm, closeTo(112.51, 0.02));
      expect(row.bestSetVolume, 720);
      expect(row.lastPerformedAt, now.subtract(const Duration(days: 1)));

      final payload = row.toSyncJson().toString();
      expect(payload, isNot(contains('Private session note')));
      expect(payload, isNot(contains('Private exercise note')));
    });

    test('ignores warmup, incomplete and invalid 1RM-domain sets', () {
      final rows = CoachExerciseProgressSnapshotBuilder.fromHistory(
        [
          session(
            id: 'mixed',
            daysAgo: 2,
            sets: const [
              WorkoutSet(
                weight: 40,
                reps: 10,
                completed: true,
                setType: WorkoutSetType.warmup,
              ),
              WorkoutSet(
                weight: 120,
                reps: 5,
                completed: false,
              ),
              WorkoutSet(
                weight: 50,
                reps: 12,
                completed: true,
                rir: 2,
              ),
            ],
          ),
        ],
        now: now,
      );

      final row = rows.single;
      expect(row.workingSets30d, 1);
      expect(row.volume30d, 600);
      expect(row.bestWeight, 50);
      expect(row.bestEstimated1Rm30d, isNull);
      expect(row.bestEstimated1Rm, isNull);
      expect(row.bestSetVolume, 600);
    });

    test('counts an exercise once per session and limits newest exercises', () {
      final repeatedStarted = now.subtract(const Duration(days: 1));
      final repeated = WorkoutSession(
        id: 'repeated',
        routineNameSnapshot: 'Upper',
        startedAt: repeatedStarted,
        finishedAt: repeatedStarted.add(const Duration(hours: 1)),
        durationSeconds: 3600,
        exercises: const [
          WorkoutExercise(
            exerciseId: 'same',
            exerciseNameSnapshot: 'Same',
            muscleGroupSnapshot: 'Back',
            sets: [
              WorkoutSet(weight: 50, reps: 10, completed: true),
            ],
          ),
          WorkoutExercise(
            exerciseId: 'same',
            exerciseNameSnapshot: 'Same',
            muscleGroupSnapshot: 'Back',
            sets: [
              WorkoutSet(weight: 55, reps: 10, completed: true),
            ],
          ),
        ],
      );

      final many = <WorkoutSession>[
        repeated,
        for (var i = 0; i < 110; i++)
          session(
            id: 's-$i',
            daysAgo: i + 2,
            exerciseId: 'exercise-$i',
            exerciseName: 'Exercise $i',
            sets: const [
              WorkoutSet(weight: 20, reps: 10, completed: true),
            ],
          ),
      ];

      final rows = CoachExerciseProgressSnapshotBuilder.fromHistory(
        many,
        now: now,
        limit: 200,
      );

      expect(rows, hasLength(100));
      final same = rows.firstWhere((item) => item.exerciseId == 'same');
      expect(same.sessions30d, 1);
      expect(same.workingSets30d, 2);
      expect(same.volume30d, 1050);
      expect(rows.first.exerciseId, 'same');
    });
  });
}
