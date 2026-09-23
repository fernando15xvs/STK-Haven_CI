import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/domain/models/progression_suggestion.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/workout_history_index.dart';
import 'package:core/features/workout/application/progression_engine.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';

/// Latest completed performance for every exercise in the active session,
/// independent of routineId. The history index avoids scanning every exercise
/// in every workout on each active-workout rebuild.
final activeWorkoutExerciseMemoryProvider =
    Provider<Map<String, ExercisePerformanceMemoryEntry>>((ref) {
  final session = ref.watch(activeWorkoutProvider.select((s) => s.session));
  if (session == null) return const {};
  final index = ref.watch(workoutHistoryIndexProvider);
  return ExercisePerformanceMemory.latestForExercisesInIndex(
    index,
    session.exercises.map((exercise) => exercise.exerciseId),
    excludeSessionId: session.id,
  );
});

final activeWorkoutSuggestionsProvider =
    Provider<Map<String, ProgressionSuggestion>>((ref) {
  final session = ref.watch(activeWorkoutProvider.select((s) => s.session));
  if (session?.routineId == null) return {};

  final routineRepo = ref.watch(routineRepositoryProvider);
  final routines = routineRepo.getAllRoutines();
  final routine = routines
      .where((candidate) => candidate.id == session!.routineId)
      .firstOrNull;
  if (routine == null) return {};

  final historyIndex = ref.watch(workoutHistoryIndexProvider);
  final memory = ref.watch(activeWorkoutExerciseMemoryProvider);
  final recovery = ref.watch(recoveryProvider);
  final settings = ref.read(settingsProvider);
  final result = <String, ProgressionSuggestion>{};

  for (final target in routine.exercises) {
    final entry = memory[target.exerciseId];
    if (entry == null) continue;

    final sourceTarget = _sourceRoutineTarget(
      routines,
      entry: entry,
      currentRoutine: routine,
      currentTarget: target,
    );
    final differentContext = _hasDifferentRepContext(
      currentRoutine: routine,
      currentTarget: target,
      entry: entry,
      sourceTarget: sourceTarget,
    );
    final latestSet = entry.latestRepresentativeSet;

    final analyzed = ProgressionEngine.analyze(
      session: entry.session,
      routineTargets: [target],
      isRirEnabled: settings.isRirEnabled,
      defaultIncrementKg: settings.defaultIncrement,
      recentSessions: _sessionsForExercise(
        historyIndex,
        target.exerciseId,
        excludeSessionId: entry.session.id,
      ),
      readiness: _readinessFor(recovery),
      sourceRoutineName: entry.routineName,
      sourcePerformedAt: entry.performedAt,
      sourceRepsMin: sourceTarget?.targetRepsMin,
      sourceRepsMax: sourceTarget?.targetRepsMax,
      sourceLastWeightKg: latestSet?.performanceWeight,
      sourceLastReps: latestSet?.performanceReps,
      sourceLastRir: latestSet?.performanceRir,
      differentContext: differentContext,
    );

    for (final suggestion in analyzed) {
      if (suggestion.exerciseId == target.exerciseId) {
        result[target.exerciseId] = suggestion;
      }
    }
  }

  return result;
});

/// Compatibility provider used by the existing mobile/web ANTERIOR column.
/// It contains the latest completed occurrence of each exercise globally, but
/// aligned to the current routine's warmup/approach/working set structure.
final activeWorkoutPreviousSessionProvider = Provider<WorkoutSession?>((ref) {
  final session = ref.watch(activeWorkoutProvider.select((s) => s.session));
  if (session == null) return null;
  final index = ref.watch(workoutHistoryIndexProvider);

  return ExercisePerformanceMemory.syntheticPreviousSessionForCurrentInIndex(
    index,
    session,
  );
});

Iterable<WorkoutSession> _sessionsForExercise(
  WorkoutHistoryIndex index,
  String exerciseId, {
  String? excludeSessionId,
}) sync* {
  final seen = <String>{};
  for (final occurrence in index.exerciseOccurrences(exerciseId)) {
    final session = occurrence.session;
    if (session.id == excludeSessionId || !seen.add(session.id)) continue;
    yield session;
  }
}

RoutineExercise? _sourceRoutineTarget(
  List<Routine> routines, {
  required ExercisePerformanceMemoryEntry entry,
  required Routine currentRoutine,
  required RoutineExercise currentTarget,
}) {
  if (entry.routineId == currentRoutine.id) return currentTarget;
  if (entry.routineId == null) return null;

  final sourceRoutine = routines
      .where((candidate) => candidate.id == entry.routineId)
      .firstOrNull;
  if (sourceRoutine == null) return null;
  return sourceRoutine.exercises
      .where((candidate) => candidate.exerciseId == entry.exerciseId)
      .firstOrNull;
}

bool _hasDifferentRepContext({
  required Routine currentRoutine,
  required RoutineExercise currentTarget,
  required ExercisePerformanceMemoryEntry entry,
  required RoutineExercise? sourceTarget,
}) {
  if (entry.routineId == currentRoutine.id) return false;

  if (sourceTarget == null) return true;

  final overlapMin = currentTarget.targetRepsMin > sourceTarget.targetRepsMin
      ? currentTarget.targetRepsMin
      : sourceTarget.targetRepsMin;
  final overlapMax = currentTarget.targetRepsMax < sourceTarget.targetRepsMax
      ? currentTarget.targetRepsMax
      : sourceTarget.targetRepsMax;
  return overlapMin > overlapMax;
}

ProgressionReadiness _readinessFor(RecoveryCheckIn? checkIn) {
  if (checkIn == null) return ProgressionReadiness.unknown;
  if (checkIn.status != RecoveryStatus.ready || checkIn.soreness >= 4) {
    return ProgressionReadiness.caution;
  }
  return ProgressionReadiness.ready;
}
