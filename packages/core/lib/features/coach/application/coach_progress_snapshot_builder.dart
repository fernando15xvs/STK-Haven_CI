import 'package:core/domain/models/coach_client_progress.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/workout_summary_snapshot.dart';

class CoachProgressSnapshotBuilder {
  const CoachProgressSnapshotBuilder._();

  static CoachClientProgress fromHistory(
    Iterable<WorkoutSession> history, {
    DateTime? now,
    int recentWorkoutLimit = 20,
  }) {
    final referenceNow = now ?? DateTime.now();
    final sevenDaysAgo = referenceNow.subtract(const Duration(days: 7));
    final thirtyDaysAgo = referenceNow.subtract(const Duration(days: 30));

    final sessions = history.toList(growable: false)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    var workouts7d = 0;
    var workouts30d = 0;
    var trainingSeconds7d = 0;
    var workingSets7d = 0;
    var volume7d = 0.0;
    var rirTotal7d = 0.0;
    var rirCount7d = 0;

    for (final session in sessions) {
      if (!session.startedAt.isBefore(thirtyDaysAgo)) {
        workouts30d++;
      }
      if (session.startedAt.isBefore(sevenDaysAgo)) continue;

      workouts7d++;
      trainingSeconds7d += session.durationSeconds < 0
          ? 0
          : session.durationSeconds;

      for (final exercise in session.exercises) {
        for (final set in exercise.sets) {
          if (!set.completed || set.setType != WorkoutSetType.working) {
            continue;
          }
          workingSets7d++;
          volume7d += set.performedVolume;
          final rir = set.performanceRir;
          if (rir != null && rir >= 0 && rir <= 10) {
            rirTotal7d += rir;
            rirCount7d++;
          }
        }
      }
    }

    final safeLimit = recentWorkoutLimit.clamp(0, 30).toInt();
    final recent = <CoachSharedWorkoutSummary>[];
    for (final session in sessions.take(safeLimit)) {
      final summary = WorkoutSummarySnapshot.fromSession(session);
      var volume = 0.0;
      for (final exercise in session.exercises) {
        for (final set in exercise.sets) {
          if (set.completed && set.setType == WorkoutSetType.working) {
            volume += set.performedVolume;
          }
        }
      }
      recent.add(
        CoachSharedWorkoutSummary(
          workoutId: _bounded(session.id, 120),
          startedAt: session.startedAt,
          routineName: _bounded(session.routineNameSnapshot, 160),
          durationSeconds:
              session.durationSeconds.clamp(0, 86400).toInt(),
          plannedWorkingSets: summary.plannedWorkingSets,
          completedWorkingSets: summary.completedWorkingSets,
          completionPercent: summary.completionPercent,
          volume: volume,
          averageRir: summary.averageRir != null &&
                  summary.averageRir! >= 0 &&
                  summary.averageRir! <= 10
              ? summary.averageRir
              : null,
        ),
      );
    }

    return CoachClientProgress(
      workouts7d: workouts7d,
      workouts30d: workouts30d,
      trainingMinutes7d: trainingSeconds7d ~/ 60,
      completedWorkingSets7d: workingSets7d,
      volume7d: volume7d,
      averageRir7d: rirCount7d == 0 ? null : rirTotal7d / rirCount7d,
      lastWorkoutAt: sessions.isEmpty ? null : sessions.first.startedAt,
      generatedAt: referenceNow,
      recentWorkouts: List.unmodifiable(recent),
    );
  }

  static String _bounded(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}
