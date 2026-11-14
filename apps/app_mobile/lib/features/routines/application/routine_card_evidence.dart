import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/todays_workout_status.dart';

/// Display-only evidence. Never infer schedule, frequency or duration from a
/// routine name or from incomplete/unlinked workout snapshots.
class RoutineCardEvidence {
  const RoutineCardEvidence({
    required this.lastFinishedAt,
    this.typicalMinutes,
  });

  final DateTime lastFinishedAt;
  final int? typicalMinutes;

  static Map<String, RoutineCardEvidence> fromHistory(
    Iterable<WorkoutSession> history, {
    DateTime? asOf,
  }) {
    final now = (asOf ?? DateTime.now()).toLocal();
    final grouped = <String, List<WorkoutSession>>{};
    for (final session in history) {
      final routineId = session.routineId;
      if (routineId == null ||
          routineId.trim().isEmpty ||
          session.finishedAt.toLocal().isAfter(now) ||
          session.finishedAt.isBefore(session.startedAt) ||
          !TodaysWorkoutStatus.isComplete(session)) {
        continue;
      }
      (grouped[routineId] ??= []).add(session);
    }

    return {
      for (final entry in grouped.entries)
        entry.key: _forRoutine(entry.value),
    };
  }

  static RoutineCardEvidence _forRoutine(List<WorkoutSession> sessions) {
    sessions.sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    // Only three or more valid recorded durations justify a typical estimate.
    final durations = sessions
        .map((session) => session.durationSeconds)
        .where((seconds) => seconds >= 300 && seconds <= 21600)
        .toList()
      ..sort();
    final typicalMinutes = durations.length < 3
        ? null
        : (durations[durations.length ~/ 2] / 60).round();
    return RoutineCardEvidence(
      lastFinishedAt: sessions.first.finishedAt.toLocal(),
      typicalMinutes: typicalMinutes,
    );
  }
}
