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
    final sessions = history
        .where((session) => session.id != currentSession.id)
        .toList(growable: false)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final occurrences = <String, List<WorkoutExerciseOccurrence>>{};
    final wanted = currentSession.exercises
        .map((exercise) => exercise.exerciseId)
        .toSet();

    for (final session in sessions) {
      for (final exercise in session.exercises) {
        if (!wanted.contains(exercise.exerciseId)) continue;
        if (!_hasCompletedWorkingSet(exercise)) continue;
        occurrences
            .putIfAbsent(exercise.exerciseId, () => [])
            .add(
              WorkoutExerciseOccurrence(
                session: session,
                exercise: exercise,
              ),
            );
      }
    }

    return _syntheticPreviousSessionFromOccurrences(
      occurrences,
      currentSession,
    );
  }

  static WorkoutSession? syntheticPreviousSessionForCurrentInIndex(
    WorkoutHistoryIndex index,
    WorkoutSession currentSession,
  ) {
    final occurrences = <String, List<WorkoutExerciseOccurrence>>{};

    for (final currentExercise in currentSession.exercises) {
      final filtered = index
          .exerciseOccurrences(currentExercise.exerciseId)
          .where(
            (occurrence) =>
                occurrence.session.id != currentSession.id &&
                _hasCompletedWorkingSet(occurrence.exercise),
          )
          .toList(growable: false);
      if (filtered.isNotEmpty) {
        occurrences[currentExercise.exerciseId] = filtered;
      }
    }

    return _syntheticPreviousSessionFromOccurrences(
      occurrences,
      currentSession,
    );
  }

  /// Builds the ANTERIOR/prefill memory slot by slot instead of letting the
  /// newest routine occurrence replace the whole exercise history.
  ///
  /// Example: Upper A may have 1 warm-up + 2 approach + 2 working sets while
  /// Upper B has 0 warm-up + 2 approach + 1 working set. After completing
  /// Upper B, returning to Upper A should keep the newest available value for
  /// every slot:
  /// - warm-up #1 can fall back to the older Upper A;
  /// - approach #1/#2 can come from the newer Upper B;
  /// - working #1 can come from Upper B;
  /// - working #2 can fall back to Upper A.
  ///
  /// Missing slots in a newer routine therefore never erase useful exercise
  /// memory from an older completed session.
  static WorkoutSession? _syntheticPreviousSessionFromOccurrences(
    Map<String, List<WorkoutExerciseOccurrence>> occurrencesByExercise,
    WorkoutSession currentSession,
  ) {
    if (occurrencesByExercise.isEmpty) return null;

    final alignedExercises = <WorkoutExercise>[];
    WorkoutExerciseOccurrence? newestUsedOccurrence;

    for (final currentExercise in currentSession.exercises) {
      final occurrences =
          occurrencesByExercise[currentExercise.exerciseId] ?? const [];
      if (occurrences.isEmpty) continue;

      final counters = <WorkoutSetType, int>{
        for (final type in WorkoutSetType.values) type: 0,
      };
      var hasRememberedSet = false;
      final alignedSets = <WorkoutSet>[];

      for (final currentSet in currentExercise.sets) {
        final type = currentSet.setType;
        final ordinal = counters[type] ?? 0;
        counters[type] = ordinal + 1;

        WorkoutSet? remembered;
        WorkoutExerciseOccurrence? rememberedFrom;

        for (final occurrence in occurrences) {
          final sameType = occurrence.exercise.sets
              .where((set) => set.setType == type)
              .toList(growable: false);

          if (ordinal >= sameType.length) continue;
          final candidate = sameType[ordinal];
          if (!candidate.completed) continue;

          remembered = _normalizedSetForPreviousDisplay(candidate);
          rememberedFrom = occurrence;
          break;
        }

        if (remembered == null) {
          alignedSets.add(
            WorkoutSet(
              weight: 0,
              reps: 0,
              completed: false,
              setType: type,
              restSeconds: currentSet.restSeconds,
              sideRestSeconds: currentSet.sideRestSeconds,
            ),
          );
          continue;
        }

        hasRememberedSet = true;
        alignedSets.add(remembered);

        if (rememberedFrom != null &&
            (newestUsedOccurrence == null ||
                rememberedFrom.date.isAfter(newestUsedOccurrence.date))) {
          newestUsedOccurrence = rememberedFrom;
        }
      }

      if (hasRememberedSet) {
        alignedExercises.add(
          currentExercise.copyWith(sets: alignedSets),
        );
      }
    }

    final newest = newestUsedOccurrence;
    if (alignedExercises.isEmpty || newest == null) return null;

    return WorkoutSession(
      id: '__exercise_memory__',
      routineId: null,
      routineNameSnapshot: 'Memoria global de ejercicios',
      startedAt: newest.session.startedAt,
      finishedAt: newest.session.finishedAt,
      exercises: alignedExercises,
      durationSeconds: 0,
      notes: '',
    );
  }

  static bool _hasCompletedWorkingSet(WorkoutExercise exercise) {
    return exercise.sets.any(
      (set) => set.setType == WorkoutSetType.working && set.completed,
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
