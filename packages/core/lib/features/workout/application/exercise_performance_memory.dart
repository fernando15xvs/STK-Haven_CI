import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/workout_history_index.dart';

/// Snapshot of the most recent completed performance for one global exercise.
///
/// `exerciseId` is the identity boundary. Routine information is context only;
/// it never changes which history belongs to the movement.
class ExercisePerformanceMemoryEntry {
  final String exerciseId;
  final WorkoutSession session;
  final WorkoutExercise exercise;

  const ExercisePerformanceMemoryEntry({
    required this.exerciseId,
    required this.session,
    required this.exercise,
  });

  String? get routineId => session.routineId;
  String get routineName => session.routineNameSnapshot;
  DateTime get performedAt => session.startedAt;

  List<WorkoutSet> get completedWorkingSets => exercise.sets
      .where((set) => set.setType == WorkoutSetType.working && set.completed)
      .toList(growable: false);

  WorkoutSet? get latestRepresentativeSet =>
      completedWorkingSets.isEmpty ? null : completedWorkingSets.last;
}

class ExercisePerformanceMemory {
  const ExercisePerformanceMemory._();

  /// Returns the newest completed occurrence of [exerciseId], regardless of
  /// routine. A same-name exercise with a different ID is intentionally not
  /// considered the same movement.
  static ExercisePerformanceMemoryEntry? latestForExercise(
    Iterable<WorkoutSession> history,
    String exerciseId, {
    String? excludeSessionId,
  }) {
    ExercisePerformanceMemoryEntry? latest;

    for (final session in history) {
      if (excludeSessionId != null && session.id == excludeSessionId) continue;

      for (final exercise in session.exercises) {
        if (exercise.exerciseId != exerciseId) continue;
        final hasCompletedWork = exercise.sets.any(
          (set) => set.setType == WorkoutSetType.working && set.completed,
        );
        if (!hasCompletedWork) continue;

        if (latest == null || session.startedAt.isAfter(latest.performedAt)) {
          latest = ExercisePerformanceMemoryEntry(
            exerciseId: exerciseId,
            session: session,
            exercise: exercise,
          );
        }
      }
    }

    return latest;
  }

  static ExercisePerformanceMemoryEntry? latestForExerciseInIndex(
    WorkoutHistoryIndex index,
    String exerciseId, {
    String? excludeSessionId,
  }) {
    final occurrence = index.latestCompletedWorkingOccurrence(
      exerciseId,
      excludeSessionId: excludeSessionId,
    );
    if (occurrence == null) return null;
    return ExercisePerformanceMemoryEntry(
      exerciseId: exerciseId,
      session: occurrence.session,
      exercise: occurrence.exercise,
    );
  }

  static Map<String, ExercisePerformanceMemoryEntry> latestForExercises(
    Iterable<WorkoutSession> history,
    Iterable<String> exerciseIds, {
    String? excludeSessionId,
  }) {
    final wanted = exerciseIds.toSet();
    final result = <String, ExercisePerformanceMemoryEntry>{};
    if (wanted.isEmpty) return result;

    for (final session in history) {
      if (excludeSessionId != null && session.id == excludeSessionId) continue;
      for (final exercise in session.exercises) {
        final id = exercise.exerciseId;
        if (!wanted.contains(id)) continue;
        if (!exercise.sets.any(
          (set) => set.setType == WorkoutSetType.working && set.completed,
        )) {
          continue;
        }

        final current = result[id];
        if (current == null || session.startedAt.isAfter(current.performedAt)) {
          result[id] = ExercisePerformanceMemoryEntry(
            exerciseId: id,
            session: session,
            exercise: exercise,
          );
        }
      }
    }
    return result;
  }

  static Map<String, ExercisePerformanceMemoryEntry> latestForExercisesInIndex(
    WorkoutHistoryIndex index,
    Iterable<String> exerciseIds, {
    String? excludeSessionId,
  }) {
    final result = <String, ExercisePerformanceMemoryEntry>{};
    for (final exerciseId in exerciseIds.toSet()) {
      final entry = latestForExerciseInIndex(
        index,
        exerciseId,
        excludeSessionId: excludeSessionId,
      );
      if (entry != null) result[exerciseId] = entry;
    }
    return result;
  }

  /// Builds a display-only synthetic previous session for the active workout.
  ///
  /// The latest occurrence is found globally by exerciseId, but the returned
  /// set list follows the *current routine's* warmup/approach/working structure.
  /// This prevents a Push A warm-up set from being shown as the previous value
  /// of a Push B working set merely because their raw indices differ.
  static WorkoutSession? syntheticPreviousSessionForCurrent(
    Iterable<WorkoutSession> history,
    WorkoutSession currentSession,
  ) {
    final entries = latestForExercises(
      history,
      currentSession.exercises.map((exercise) => exercise.exerciseId),
      excludeSessionId: currentSession.id,
    );
    return _syntheticPreviousSessionForEntries(entries, currentSession);
  }

  static WorkoutSession? syntheticPreviousSessionForCurrentInIndex(
    WorkoutHistoryIndex index,
    WorkoutSession currentSession,
  ) {
    final entries = latestForExercisesInIndex(
      index,
      currentSession.exercises.map((exercise) => exercise.exerciseId),
      excludeSessionId: currentSession.id,
    );
    return _syntheticPreviousSessionForEntries(entries, currentSession);
  }

  static WorkoutSession? _syntheticPreviousSessionForEntries(
    Map<String, ExercisePerformanceMemoryEntry> entries,
    WorkoutSession currentSession,
  ) {
    if (entries.isEmpty) return null;

    final newest = entries.values.reduce(
      (a, b) => a.performedAt.isAfter(b.performedAt) ? a : b,
    );

    final alignedExercises = <WorkoutExercise>[];
    for (final currentExercise in currentSession.exercises) {
      final entry = entries[currentExercise.exerciseId];
      if (entry == null) continue;
      alignedExercises.add(
        _alignExerciseToCurrent(
          source: entry.exercise,
          current: currentExercise,
        ),
      );
    }

    return WorkoutSession(
      id: '__exercise_memory__',
      routineId: null,
      routineNameSnapshot: 'Memoria global de ejercicios',
      startedAt: newest.performedAt,
      finishedAt: newest.session.finishedAt,
      exercises: alignedExercises,
      durationSeconds: 0,
      notes: '',
    );
  }

  /// Backward-compatible helper kept for tests/consumers without a current
  /// session shape. Prefer [syntheticPreviousSessionForCurrent] in workout UI.
  static WorkoutSession? syntheticPreviousSession(
    Iterable<WorkoutSession> history,
    Iterable<String> exerciseIds, {
    String? excludeSessionId,
  }) {
    final entries = latestForExercises(
      history,
      exerciseIds,
      excludeSessionId: excludeSessionId,
    );
    if (entries.isEmpty) return null;

    final newest = entries.values.reduce(
      (a, b) => a.performedAt.isAfter(b.performedAt) ? a : b,
    );

    return WorkoutSession(
      id: '__exercise_memory__',
      routineId: null,
      routineNameSnapshot: 'Memoria global de ejercicios',
      startedAt: newest.performedAt,
      finishedAt: newest.session.finishedAt,
      exercises: entries.values
          .map((entry) => _normalizedForPreviousDisplay(entry.exercise))
          .toList(growable: false),
      durationSeconds: 0,
      notes: '',
    );
  }

  static WorkoutExercise _alignExerciseToCurrent({
    required WorkoutExercise source,
    required WorkoutExercise current,
  }) {
    final sourceByType = <WorkoutSetType, List<WorkoutSet>>{
      for (final type in WorkoutSetType.values)
        type: source.sets
            .where((set) => set.setType == type)
            .map(_normalizedSetForPreviousDisplay)
            .toList(growable: false),
    };
    final counters = <WorkoutSetType, int>{
      for (final type in WorkoutSetType.values) type: 0,
    };

    final aligned = current.sets.map((currentSet) {
      final type = currentSet.setType;
      final ordinal = counters[type] ?? 0;
      counters[type] = ordinal + 1;
      final candidates = sourceByType[type] ?? const <WorkoutSet>[];
      if (ordinal < candidates.length) return candidates[ordinal];

      return WorkoutSet(
        weight: 0,
        reps: 0,
        completed: false,
        setType: type,
        restSeconds: currentSet.restSeconds,
        sideRestSeconds: currentSet.sideRestSeconds,
      );
    }).toList(growable: false);

    return source.copyWith(sets: aligned);
  }

  static WorkoutExercise _normalizedForPreviousDisplay(
    WorkoutExercise exercise,
  ) {
    return exercise.copyWith(
      sets: exercise.sets
          .map(_normalizedSetForPreviousDisplay)
          .toList(growable: false),
    );
  }

  static WorkoutSet _normalizedSetForPreviousDisplay(WorkoutSet set) {
    if (!set.hasDetailedSideData) return set;
    return set.copyWith(
      weight: set.performanceWeight,
      reps: set.performanceReps,
      rir: set.performanceRir,
      clearRir: set.performanceRir == null,
    );
  }
}
