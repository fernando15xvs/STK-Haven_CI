import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';

/// Read-only training distribution based exclusively on completed working sets.
/// Indirect exposure is a *separate estimate* based on the CURRENT exercise
/// catalogue; it is never merged into direct working sets or saved to history.
class MuscleBalanceReport {
  final List<MuscleBalanceItem> groups;
  final DateTime recentWeekStart;
  final DateTime previousWeekStart;
  final int sessionsWithComparablePlan;

  const MuscleBalanceReport({
    required this.groups,
    required this.recentWeekStart,
    required this.previousWeekStart,
    required this.sessionsWithComparablePlan,
  });

  int get totalDirectSets =>
      groups.fold(0, (sum, item) => sum + item.directSets);
  bool get hasRecordedWork => totalDirectSets > 0;
}

class MuscleBalanceItem {
  final String name;
  final int directSets;
  final double estimatedSecondarySets;
  final int trainingDays;
  final DateTime? lastTrainedAt;
  final Map<String, int> directExerciseSets;
  final int previousFullWeekSets;
  final int recentFullWeekSets;
  final int previousFullWeekDays;
  final int recentFullWeekDays;

  /// Null means there was no comparable performed session associated with
  /// a currently available routine. This is NOT a historical plan snapshot.
  final int? plannedSetsInPerformedSessions;
  final int completedSetsInPlannedExercises;

  const MuscleBalanceItem({
    required this.name,
    required this.directSets,
    required this.estimatedSecondarySets,
    required this.trainingDays,
    required this.lastTrainedAt,
    required this.directExerciseSets,
    required this.previousFullWeekSets,
    required this.recentFullWeekSets,
    required this.previousFullWeekDays,
    required this.recentFullWeekDays,
    required this.plannedSetsInPerformedSessions,
    required this.completedSetsInPlannedExercises,
  });
}

class _MuscleAccumulator {
  final String name;
  int directSets = 0;
  double estimatedSecondarySets = 0;
  DateTime? lastTrainedAt;
  final Set<String> trainingDates = {};
  final Set<String> lastFullWeekDates = {};
  final Set<String> previousFullWeekDates = {};
  final Map<String, int> contributions = {};
  int recentWeekSets = 0;
  int previousWeekSets = 0;
  int? planned;
  int completedAgainstPlan = 0;
  _MuscleAccumulator(this.name);
}

class MuscleBalanceCalculator {
  const MuscleBalanceCalculator._();

  static MuscleBalanceReport calculate({
    required Iterable<WorkoutSession> history,
    required Iterable<Exercise> exercises,
    Iterable<Routine> routines = const [],
    required DateTime from,
    required DateTime now,
  }) {
    final exerciseMap = {for (final e in exercises) e.id: e};
    final routineMap = {for (final r in routines) r.id: r};
    final groups = <String, _MuscleAccumulator>{};

    _MuscleAccumulator ensure(String raw) {
      final name = raw.trim();
      final key = name.toLowerCase();
      return groups.putIfAbsent(key, () => _MuscleAccumulator(name));
    }

    // Include known muscle groups even when there is no activity. The
    // catalogue may include groups with no corresponding training history.
    for (final exercise in exercises) {
      if (exercise.muscleGroup.trim().isNotEmpty) {
        ensure(exercise.muscleGroup);
      }
      for (final secondary in exercise.secondaryMuscles) {
        if (secondary.trim().isNotEmpty) ensure(secondary);
      }
    }

    DateTime day(DateTime date) {
      final local = date.toLocal();
      return DateTime(local.year, local.month, local.day);
    }

    // Only COMPLETED Monday–Sunday calendar weeks are compared, never the
    // current partial week. They are independent of the rolling filter.
    final today = day(now);
    final recentEnd = today.subtract(Duration(days: today.weekday - 1));
    final recentStart = recentEnd.subtract(const Duration(days: 7));
    final previousStart = recentStart.subtract(const Duration(days: 7));
    final fromDate = from;
    var comparableSessions = 0;

    for (final session in history) {
      // The last-completed-week comparison may predate the selected window.
      // Never include sessions dated in the future.
      final finished = session.finishedAt;
      if (finished.isAfter(now)) continue;
      final inPeriod = !finished.isBefore(fromDate);
      final localDay = day(finished);
      final dateKey = '${localDay.year}-${localDay.month}-${localDay.day}';
      final inRecent = !localDay.isBefore(recentStart) &&
          localDay.isBefore(recentEnd);
      final inPrevious = !localDay.isBefore(previousStart) &&
          localDay.isBefore(recentStart);
      if (!inPeriod && !inRecent && !inPrevious) continue;

      // One current routine template per recorded session, not hypothetical
      // future sessions. This comparison does not reconstruct past edits.
      final routine = inPeriod && session.routineId != null
          ? routineMap[session.routineId] : null;
      final templateTargets = <String, int>{};
      if (routine != null) {
        comparableSessions++;
        for (final target in routine.exercises) {
          if (target.phase != RoutineExercisePhase.main ||
              target.targetSets <= 0) continue;
          templateTargets.update(
            target.exerciseId,
            (value) => value + target.targetSets,
            ifAbsent: () => target.targetSets,
          );
          final group = exerciseMap[target.exerciseId]?.muscleGroup.trim();
          if (group != null && group.isNotEmpty) {
            final accumulator = ensure(group);
            accumulator.planned =
                (accumulator.planned ?? 0) + target.targetSets;
          }
        }
      }

      for (final exercise in session.exercises) {
        final primary = exercise.muscleGroupSnapshot.trim().isNotEmpty
            ? exercise.muscleGroupSnapshot.trim()
            : (exerciseMap[exercise.exerciseId]?.muscleGroup ?? '').trim();
        if (primary.isEmpty) continue;
        final validSets = exercise.sets.where((set) =>
            set.setType == WorkoutSetType.working && set.completed).length;
        if (validSets == 0) continue;

        final item = ensure(primary);
        if (inPeriod) {
          item.directSets += validSets;
          item.trainingDates.add(dateKey);
          if (item.lastTrainedAt == null ||
              finished.isAfter(item.lastTrainedAt!)) {
            item.lastTrainedAt = finished;
          }
          final label = exercise.exerciseNameSnapshot.trim().isNotEmpty
              ? exercise.exerciseNameSnapshot.trim()
              : (exerciseMap[exercise.exerciseId]?.name ??
                  'Ejercicio sin nombre');
          item.contributions.update(
            label, (count) => count + validSets,
            ifAbsent: () => validSets,
          );
          if (templateTargets.containsKey(exercise.exerciseId)) {
            item.completedAgainstPlan += validSets;
          }

          // Secondary muscles are identified by the current catalogue, not
          // by immutable workout history. Estimate 0.5 per completed set and
          // keep this outside direct counts. Deduplicate each secondary.
          final secondaryKeys = <String>{};
          for (final secondary in exerciseMap[exercise.exerciseId]
                  ?.secondaryMuscles ?? const <String>[]) {
            final label = secondary.trim();
            final key = label.toLowerCase();
            if (label.isEmpty || key == primary.toLowerCase() ||
                !secondaryKeys.add(key)) continue;
            ensure(label).estimatedSecondarySets += validSets * 0.5;
          }
        }
        if (inRecent) {
          item.recentWeekSets += validSets;
          item.lastFullWeekDates.add(dateKey);
        }
        if (inPrevious) {
          item.previousWeekSets += validSets;
          item.previousFullWeekDates.add(dateKey);
        }
      }
    }

    final rows = [
      for (final item in groups.values)
        MuscleBalanceItem(
          name: item.name,
          directSets: item.directSets,
          estimatedSecondarySets: item.estimatedSecondarySets,
          trainingDays: item.trainingDates.length,
          lastTrainedAt: item.lastTrainedAt,
          directExerciseSets: Map.unmodifiable(item.contributions),
          previousFullWeekSets: item.previousWeekSets,
          recentFullWeekSets: item.recentWeekSets,
          previousFullWeekDays: item.previousFullWeekDates.length,
          recentFullWeekDays: item.lastFullWeekDates.length,
          plannedSetsInPerformedSessions: item.planned,
          completedSetsInPlannedExercises: item.completedAgainstPlan,
        ),
    ]..sort((a, b) {
        final direct = b.directSets.compareTo(a.directSets);
        if (direct != 0) return direct;
        final indirect =
            b.estimatedSecondarySets.compareTo(a.estimatedSecondarySets);
        return indirect != 0 ? indirect : a.name.compareTo(b.name);
      });

    return MuscleBalanceReport(
      groups: List.unmodifiable(rows),
      recentWeekStart: recentStart,
      previousWeekStart: previousStart,
      sessionsWithComparablePlan: comparableSessions,
    );
  }
}
