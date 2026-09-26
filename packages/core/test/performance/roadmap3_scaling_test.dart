import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/coach/application/coach_progress_snapshot_builder.dart';
import 'package:core/features/programs/application/program_rotation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 1, 1, 8);

  WorkoutSession session(int index, {String? routineId}) {
    final at = start.add(Duration(hours: index * 6));
    return WorkoutSession(
      id: 'session-$index',
      routineId: routineId,
      routineNameSnapshot: routineId ?? 'Libre',
      startedAt: at,
      finishedAt: at.add(const Duration(hours: 1)),
      durationSeconds: 3600,
      exercises: const <WorkoutExercise>[],
    );
  }

  TrainingProgram program() => TrainingProgram(
        id: 'scale-program',
        name: 'Scale',
        routineIds: const ['A', 'B', 'C', 'D'],
        createdAt: start,
        startedAt: start,
        durationWeeks: 520,
      );

  test('rotation reconciliation handles 1k and 5k sessions within budget', () {
    for (final count in <int>[1000, 5000]) {
      final history = <WorkoutSession>[
        for (var i = 0; i < count; i++)
          session(
            i,
            routineId: const ['A', 'B', 'C', 'D'][i % 4],
          ),
      ];

      final stopwatch = Stopwatch()..start();
      final reconciled = ProgramRotationCoordinator.reconcile(
        program(),
        history,
      );
      stopwatch.stop();

      expect(reconciled.completions, hasLength(count));
      expect(reconciled.nextRotationIndex, count % 4);
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 15)),
        reason:
            'Regression budget exceeded for $count sessions: '
            '${stopwatch.elapsedMilliseconds} ms',
      );

      // ignore: avoid_print
      print(
        'roadmap3.rotation.$count='
        '${stopwatch.elapsedMilliseconds}ms',
      );
    }
  });

  test('coach snapshot scales across 25 and 100 clients with bounded payload',
      () {
    final now = start.add(const Duration(days: 40));

    for (final clientCount in <int>[25, 100]) {
      final stopwatch = Stopwatch()..start();
      var totalRecentPayloadRows = 0;

      for (var client = 0; client < clientCount; client++) {
        final history = <WorkoutSession>[
          for (var i = 0; i < 50; i++)
            WorkoutSession(
              id: 'client-$client-session-$i',
              routineNameSnapshot: 'Routine',
              startedAt: now.subtract(Duration(hours: i * 12)),
              finishedAt:
                  now.subtract(Duration(hours: i * 12)).add(
                        const Duration(minutes: 50),
                      ),
              durationSeconds: 3000,
              exercises: const <WorkoutExercise>[],
            ),
        ];

        final progress = CoachProgressSnapshotBuilder.fromHistory(
          history,
          now: now,
          recentWorkoutLimit: 20,
        );
        expect(progress.recentWorkouts.length, lessThanOrEqualTo(20));
        totalRecentPayloadRows += progress.recentWorkouts.length;
      }

      stopwatch.stop();

      expect(
        totalRecentPayloadRows,
        lessThanOrEqualTo(clientCount * 20),
      );
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 15)),
        reason:
            'Regression budget exceeded for $clientCount clients: '
            '${stopwatch.elapsedMilliseconds} ms',
      );

      // ignore: avoid_print
      print(
        'roadmap3.coach.$clientCount='
        '${stopwatch.elapsedMilliseconds}ms',
      );
    }
  });
}
