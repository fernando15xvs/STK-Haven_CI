import 'dart:math' as math;

import '../../../domain/models/progression_suggestion.dart';
import '../../../domain/models/routine.dart';
import '../../../domain/models/workout_session.dart';

class ProgressionEngine {
  static const int confirmationSessions = 2;
  static const int minimumRirForIncrease = 2;
  static const double maximumRelativeIncrease = 0.05;

  /// Produces one explained progression reference per exercised target.
  ///
  /// Exercise identity is global: history is matched by `exerciseId`, never by
  /// `routineId`. Routine data remains contextual (target sets/reps/rest), so
  /// the same Press Inclinado can carry performance evidence across Push A/B/C.
  ///
  /// A load increase requires two comparable completed performances at the top
  /// of the current target range. When RIR is enabled, every required working
  /// set must include RIR >= [minimumRirForIncrease].
  ///
  /// When [differentContext] is true, the latest evidence comes from a routine
  /// whose repetition range is not directly comparable. In that case the
  /// engine intentionally avoids an automatic load increase: it exposes e1RM
  /// plus RIR context and keeps the latest load as a conservative reference.
  ///
  /// For detailed unilateral sets, the conservative/limiting side is used for
  /// progression via WorkoutSet.performance* getters.
  static List<ProgressionSuggestion> analyze({
    required WorkoutSession session,
    required List<RoutineExercise> routineTargets,
    required bool isRirEnabled,
    required double defaultIncrementKg,
    Iterable<WorkoutSession> recentSessions = const [],
    ProgressionReadiness readiness = ProgressionReadiness.unknown,
    String? sourceRoutineName,
    DateTime? sourcePerformedAt,
    int? sourceRepsMin,
    int? sourceRepsMax,
    double? sourceLastWeightKg,
    int? sourceLastReps,
    int? sourceLastRir,
    bool differentContext = false,
  }) {
    final suggestions = <ProgressionSuggestion>[];
    final orderedHistory = recentSessions
        .where((candidate) => candidate.id != session.id)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    for (final exercise in session.exercises) {
      final target = routineTargets
          .where((item) => item.exerciseId == exercise.exerciseId)
          .firstOrNull;
      if (target == null) continue;

      final current = _evidenceFor(
        session,
        target,
        isRirEnabled: isRirEnabled,
      );
      if (current == null) continue;

      final previous = differentContext
          ? null
          : _previousEvidence(
              orderedHistory,
              target,
              isRirEnabled: isRirEnabled,
            );
      final evidenceCount = previous == null ? 1 : confirmationSessions;

      ProgressionSuggestion result({
        required ProgressionType type,
        required ProgressionReason reason,
        required double suggestedWeightKg,
      }) {
        return ProgressionSuggestion(
          exerciseId: exercise.exerciseId,
          exerciseName: exercise.exerciseNameSnapshot,
          currentWeightKg: current.averageWeightKg,
          suggestedWeightKg: suggestedWeightKg,
          suggestedRepsMin: target.targetRepsMin,
          suggestedRepsMax: target.targetRepsMax,
          type: type,
          reason: reason,
          evidenceSessions: evidenceCount,
          sourceRoutineName: sourceRoutineName,
          sourcePerformedAt: sourcePerformedAt,
          sourceRepsMin: sourceRepsMin,
          sourceRepsMax: sourceRepsMax,
          sourceLastWeightKg: sourceLastWeightKg,
          sourceLastReps: sourceLastReps,
          sourceLastRir: sourceLastRir,
          differentContext: differentContext,
          sourceEstimated1RmKg:
              differentContext ? current.estimated1RmKg : null,
        );
      }

      if (differentContext) {
        if (current.averageWeightKg <= 0) {
          suggestions.add(
            result(
              type: ProgressionType.insufficientData,
              reason: ProgressionReason.invalidLoad,
              suggestedWeightKg: current.averageWeightKg,
            ),
          );
          continue;
        }

        if (isRirEnabled && !current.hasCompleteRir) {
          suggestions.add(
            result(
              type: ProgressionType.maintain,
              reason: ProgressionReason.missingRir,
              suggestedWeightKg: current.averageWeightKg,
            ),
          );
          continue;
        }

        if (readiness == ProgressionReadiness.caution) {
          suggestions.add(
            result(
              type: ProgressionType.maintain,
              reason: ProgressionReason.recoveryCaution,
              suggestedWeightKg: current.averageWeightKg,
            ),
          );
          continue;
        }

        suggestions.add(
          result(
            type: ProgressionType.maintain,
            reason: ProgressionReason.differentRepContext,
            suggestedWeightKg: current.averageWeightKg,
          ),
        );
        continue;
      }

      if (!current.hasRequiredSets) {
        suggestions.add(
          result(
            type: ProgressionType.insufficientData,
            reason: ProgressionReason.incompleteWorkSets,
            suggestedWeightKg: current.averageWeightKg,
          ),
        );
        continue;
      }

      if (!current.reachedTopRange) {
        suggestions.add(
          result(
            type: ProgressionType.maintain,
            reason: ProgressionReason.buildRepetitions,
            suggestedWeightKg: current.averageWeightKg,
          ),
        );
        continue;
      }

      if (isRirEnabled && !current.hasCompleteRir) {
        suggestions.add(
          result(
            type: ProgressionType.maintain,
            reason: ProgressionReason.missingRir,
            suggestedWeightKg: current.averageWeightKg,
          ),
        );
        continue;
      }

      if (isRirEnabled && !current.hasEffortMargin) {
        suggestions.add(
          result(
            type: ProgressionType.maintain,
            reason: ProgressionReason.effortTooHigh,
            suggestedWeightKg: current.averageWeightKg,
          ),
        );
        continue;
      }

      if (readiness == ProgressionReadiness.caution) {
        suggestions.add(
          result(
            type: ProgressionType.maintain,
            reason: ProgressionReason.recoveryCaution,
            suggestedWeightKg: current.averageWeightKg,
          ),
        );
        continue;
      }

      final confirmed = previous != null &&
          previous.hasRequiredSets &&
          previous.reachedTopRange &&
          (!isRirEnabled ||
              (previous.hasCompleteRir && previous.hasEffortMargin)) &&
          _sameLoad(
            current.averageWeightKg,
            previous.averageWeightKg,
          );

      if (!confirmed) {
        suggestions.add(
          result(
            type: ProgressionType.maintain,
            reason: ProgressionReason.confirmTopRange,
            suggestedWeightKg: current.averageWeightKg,
          ),
        );
        continue;
      }

      if (current.averageWeightKg <= 0 || defaultIncrementKg <= 0) {
        suggestions.add(
          result(
            type: ProgressionType.insufficientData,
            reason: ProgressionReason.invalidLoad,
            suggestedWeightKg: current.averageWeightKg,
          ),
        );
        continue;
      }

      final relativeCap = current.averageWeightKg * maximumRelativeIncrease;
      final safeIncrement = math.min(defaultIncrementKg, relativeCap);
      suggestions.add(
        result(
          type: ProgressionType.increase,
          reason: ProgressionReason.consistentTopRange,
          suggestedWeightKg: current.averageWeightKg + safeIncrement,
        ),
      );
    }

    return suggestions;
  }

  static _ExerciseEvidence? _previousEvidence(
    List<WorkoutSession> orderedHistory,
    RoutineExercise target, {
    required bool isRirEnabled,
  }) {
    for (final candidate in orderedHistory) {
      final evidence = _evidenceFor(
        candidate,
        target,
        isRirEnabled: isRirEnabled,
      );
      if (evidence != null) return evidence;
    }
    return null;
  }

  static _ExerciseEvidence? _evidenceFor(
    WorkoutSession session,
    RoutineExercise target, {
    required bool isRirEnabled,
  }) {
    final exercise = session.exercises
        .where((item) => item.exerciseId == target.exerciseId)
        .firstOrNull;
    if (exercise == null) return null;

    final completedAll = exercise.sets
        .where((set) => set.completed && !set.warmup)
        .toList(growable: false);
    if (completedAll.isEmpty) return null;

    final completed = completedAll
        .take(target.targetSets)
        .toList(growable: false);
    final averageWeight = completed.fold<double>(
          0,
          (sum, set) => sum + set.performanceWeight,
        ) /
        completed.length;
    final hasRequiredSets = completed.length >= target.targetSets;
    final reachedTopRange = hasRequiredSets &&
        completed.every((set) => set.performanceReps >= target.targetRepsMax);
    final hasCompleteRir = !isRirEnabled ||
        completedAll.every((set) => set.performanceRir != null);
    final hasEffortMargin = !isRirEnabled ||
        completed.every(
          (set) =>
              set.performanceRir != null &&
              set.performanceRir! >= minimumRirForIncrease,
        );

    double? estimated1RmKg;
    for (final set in completedAll) {
      final weight = set.performanceWeight;
      final reps = set.performanceReps;
      if (weight <= 0 || reps <= 0) continue;
      final rir = isRirEnabled ? (set.performanceRir ?? 0) : 0;
      final effectiveReps = math.max(1, reps + rir);
      final estimate = weight * (1 + effectiveReps / 30.0);
      if (estimated1RmKg == null || estimate > estimated1RmKg) {
        estimated1RmKg = estimate;
      }
    }

    return _ExerciseEvidence(
      averageWeightKg: averageWeight,
      hasRequiredSets: hasRequiredSets,
      reachedTopRange: reachedTopRange,
      hasCompleteRir: hasCompleteRir,
      hasEffortMargin: hasEffortMargin,
      estimated1RmKg: estimated1RmKg,
    );
  }

  static bool _sameLoad(double current, double previous) {
    if (current <= 0 || previous <= 0) return false;
    final tolerance = math.max(0.1, current.abs() * 0.01);
    return (current - previous).abs() <= tolerance;
  }
}

class _ExerciseEvidence {
  final double averageWeightKg;
  final bool hasRequiredSets;
  final bool reachedTopRange;
  final bool hasCompleteRir;
  final bool hasEffortMargin;
  final double? estimated1RmKg;

  const _ExerciseEvidence({
    required this.averageWeightKg,
    required this.hasRequiredSets,
    required this.reachedTopRange,
    required this.hasCompleteRir,
    required this.hasEffortMargin,
    required this.estimated1RmKg,
  });
}
