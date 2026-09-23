import 'dart:collection';

import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WorkoutExerciseOccurrence {
  final WorkoutSession session;
  final WorkoutExercise exercise;

  const WorkoutExerciseOccurrence({
    required this.session,
    required this.exercise,
  });

  DateTime get date => session.startedAt;
}

/// Immutable lookup structure built once per workout-history state change.
class WorkoutHistoryIndex {
  final List<WorkoutSession> sessionsNewestFirst;
  final Map<String, List<WorkoutExerciseOccurrence>> byExerciseId;
  final Map<String, List<WorkoutSession>> byRoutineId;

  WorkoutHistoryIndex._({
    required this.sessionsNewestFirst,
    required this.byExerciseId,
    required this.byRoutineId,
  });

  factory WorkoutHistoryIndex.build(Iterable<WorkoutSession> history) {
    final sessions = history.toList(growable: false)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final exerciseMap = <String, List<WorkoutExerciseOccurrence>>{};
    final routineMap = <String, List<WorkoutSession>>{};

    for (final session in sessions) {
      final routineId = session.routineId;
      if (routineId != null) {
        routineMap.putIfAbsent(routineId, () => []).add(session);
      }
      for (final exercise in session.exercises) {
        exerciseMap
            .putIfAbsent(exercise.exerciseId, () => [])
            .add(WorkoutExerciseOccurrence(session: session, exercise: exercise));
      }
    }

    return WorkoutHistoryIndex._(
      sessionsNewestFirst: List.unmodifiable(sessions),
      byExerciseId: UnmodifiableMapView(
        exerciseMap.map(
          (key, value) => MapEntry(key, List.unmodifiable(value)),
        ),
      ),
      byRoutineId: UnmodifiableMapView(
        routineMap.map(
          (key, value) => MapEntry(key, List.unmodifiable(value)),
        ),
      ),
    );
  }

  List<WorkoutExerciseOccurrence> exerciseOccurrences(
    String exerciseId, {
    DateTime? from,
    DateTime? to,
  }) {
    final source = byExerciseId[exerciseId] ?? const [];
    if (from == null && to == null) return source;
    return source
        .where((occurrence) {
          if (from != null && occurrence.date.isBefore(from)) return false;
          if (to != null && !occurrence.date.isBefore(to)) return false;
          return true;
        })
        .toList(growable: false);
  }

  WorkoutExerciseOccurrence? latestCompletedWorkingOccurrence(
    String exerciseId, {
    String? excludeSessionId,
  }) {
    for (final occurrence in byExerciseId[exerciseId] ?? const []) {
      if (excludeSessionId != null && occurrence.session.id == excludeSessionId) {
        continue;
      }
      final hasCompletedWorking = occurrence.exercise.sets.any(
        (set) => set.setType == WorkoutSetType.working && set.completed,
      );
      if (hasCompletedWorking) return occurrence;
    }
    return null;
  }

  List<WorkoutSession> routineSessions(String routineId) =>
      byRoutineId[routineId] ?? const [];
}

final workoutHistoryIndexProvider = Provider<WorkoutHistoryIndex>((ref) {
  final history = ref.watch(workoutHistoryProvider);
  return WorkoutHistoryIndex.build(history);
});
