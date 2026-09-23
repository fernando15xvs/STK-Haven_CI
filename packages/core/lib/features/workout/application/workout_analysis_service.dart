import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/workout_session.dart';
import '../../../domain/models/workout_analysis.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import '../presentation/providers/personal_record_provider.dart';
import 'package:core/domain/models/progression_suggestion.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'exercise_session_comparison.dart';
import 'pr_detector.dart';
import 'plateau_detector.dart';
import 'progression_engine.dart';
import 'workout_comparator.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/application/gamification_provider.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';

final workoutAnalysisServiceProvider = Provider<WorkoutAnalysisService>((ref) {
  return WorkoutAnalysisService(ref);
});

class WorkoutAnalysisService {
  final Ref _ref;

  WorkoutAnalysisService(this._ref);

  Future<WorkoutAnalysisResult> analyze(WorkoutSession session) async {
    final prRepo = _ref.read(personalRecordRepositoryProvider);
    final routineRepo = _ref.read(routineRepositoryProvider);
    final history = _ref.read(workoutHistoryProvider);

    // 1. Detect PRs
    final newPRs = PRDetector.analyze(
      session: session,
      getBestPreviousValue: (exerciseId, type) =>
          prRepo.getBestValue(exerciseId, type),
    );

    // 2. Progression Engine & Plateau Detection
    List<ProgressionSuggestion> suggestions = [];
    List<ProgressionSuggestion> deloads = [];
    if (session.routineId != null) {
      final routine = routineRepo
          .getAllRoutines()
          .where((r) => r.id == session.routineId)
          .firstOrNull;
      if (routine != null) {
        final settings = _ref.read(settingsProvider);
        final isRirEnabled = settings.isRirEnabled;
        final defaultIncrement = settings.defaultIncrement;
        final recovery = _ref.read(recoveryProvider);

        suggestions = ProgressionEngine.analyze(
          session: session,
          routineTargets: routine.exercises,
          isRirEnabled: isRirEnabled,
          defaultIncrementKg: defaultIncrement,
          recentSessions: history,
          readiness: _readinessForSession(recovery, session.startedAt),
        );

        for (final target in routine.exercises) {
          final isPlateau = PlateauDetector.hasPlateaued(
            history: history,
            exerciseId: target.exerciseId,
            targetRepsMin: target.targetRepsMin,
          );

          if (isPlateau) {
            final currEx = session.exercises
                .where((e) => e.exerciseId == target.exerciseId)
                .firstOrNull;
            if (currEx != null &&
                currEx.sets.any((s) => s.completed && !s.warmup)) {
              final bestSet = currEx.sets
                  .where((s) => s.completed && !s.warmup)
                  .reduce(
                    (a, b) => a.performanceWeight > b.performanceWeight
                        ? a
                        : b,
                  );
              final referenceWeight = bestSet.performanceWeight;

              deloads.add(
                ProgressionSuggestion(
                  exerciseId: target.exerciseId,
                  exerciseName: currEx.exerciseNameSnapshot,
                  currentWeightKg: referenceWeight,
                  suggestedWeightKg: referenceWeight * 0.90,
                  suggestedRepsMin: target.targetRepsMin,
                  suggestedRepsMax: target.targetRepsMax,
                  type: ProgressionType.deload,
                  reason: ProgressionReason.plateau,
                  evidenceSessions: 3,
                ),
              );
            }
          }
        }
      }
    }

    // 3. Session-level comparison stays routine-scoped intentionally because
    // total workout volume/duration should compare equivalent routine context.
    WorkoutSession? previousSession;
    if (session.routineId != null) {
      try {
        previousSession = history.firstWhere(
          (s) => s.routineId == session.routineId && s.id != session.id,
        );
      } catch (_) {
        // No previous session
      }
    }

    final comparison = WorkoutComparator.compare(
      currentSession: session,
      previousSession: previousSession,
    );

    // Exercise-level comparison is intentionally global by exerciseId. This
    // lets Push A, Push B or a free workout share the same movement memory.
    final exerciseComparisons = ExerciseSessionComparison.build(
      currentSession: session,
      history: history,
    );

    // 4. Save PRs
    if (newPRs.isNotEmpty) {
      await prRepo.savePRs(newPRs);
      _ref.read(gamificationProvider.notifier).checkFirstPr();
    }

    // 5. Build Result
    return WorkoutAnalysisResult(
      session: session,
      totalVolume: WorkoutComparator.calculateVolume(session),
      completedSetsCount: WorkoutComparator.calculateSets(session),
      durationSeconds: session.durationSeconds,
      personalRecords: newPRs,
      progressionSuggestions: suggestions,
      deloadSuggestions: deloads,
      comparison: comparison,
      exerciseComparisons: exerciseComparisons,
    );
  }
}

ProgressionReadiness _readinessForSession(
  RecoveryCheckIn? checkIn,
  DateTime sessionDate,
) {
  if (checkIn == null || !_sameCalendarDay(checkIn.date, sessionDate)) {
    return ProgressionReadiness.unknown;
  }
  if (checkIn.status != RecoveryStatus.ready || checkIn.soreness >= 4) {
    return ProgressionReadiness.caution;
  }
  return ProgressionReadiness.ready;
}

bool _sameCalendarDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
