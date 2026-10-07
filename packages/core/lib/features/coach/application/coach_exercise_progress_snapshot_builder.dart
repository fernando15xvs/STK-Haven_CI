import 'package:core/core/utils/fitness_math.dart';
import 'package:core/domain/models/coach_exercise_progress.dart';
import 'package:core/domain/models/workout_session.dart';

class CoachExerciseProgressSnapshotBuilder {
  const CoachExerciseProgressSnapshotBuilder._();

  static List<CoachExerciseProgressSummary> fromHistory(
    Iterable<WorkoutSession> history, {
    DateTime? now,
    int limit = 100,
  }) {
    final referenceNow = now ?? DateTime.now();
    final currentStart = referenceNow.subtract(const Duration(days: 30));
    final previousStart = referenceNow.subtract(const Duration(days: 60));
    final safeLimit = limit.clamp(0, 100).toInt();

    final sessions = history.toList(growable: false)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final byExercise = <String, _ExerciseAccumulator>{};

    for (final session in sessions) {
      final inCurrent = !session.startedAt.isBefore(currentStart) &&
          session.startedAt.isBefore(referenceNow);
      final inPrevious = session.startedAt.isBefore(currentStart) &&
          !session.startedAt.isBefore(previousStart);

      for (final exercise in session.exercises) {
        final exerciseId = exercise.exerciseId.trim();
        if (exerciseId.isEmpty || exerciseId.runes.length > 120) continue;

        final completedWorking = exercise.sets
            .where(
              (set) =>
                  set.completed &&
                  set.setType == WorkoutSetType.working &&
                  set.performanceReps > 0,
            )
            .toList(growable: false);
        if (completedWorking.isEmpty) continue;

        final accumulator = byExercise.putIfAbsent(
          exerciseId,
          () => _ExerciseAccumulator(
            exerciseId: exerciseId,
            exerciseName: _bounded(exercise.exerciseNameSnapshot, 160),
            muscleGroup: _bounded(exercise.muscleGroupSnapshot, 120),
            lastPerformedAt: session.startedAt,
          ),
        );

        if (session.startedAt.isAfter(accumulator.lastPerformedAt)) {
          accumulator
            ..exerciseName = _bounded(exercise.exerciseNameSnapshot, 160)
            ..muscleGroup = _bounded(exercise.muscleGroupSnapshot, 120)
            ..lastPerformedAt = session.startedAt;
        }

        if (inCurrent) {
          accumulator.currentSessionIds.add(session.id);
        } else if (inPrevious) {
          accumulator.previousSessionIds.add(session.id);
        }

        for (final set in completedWorking) {
          final weight = set.performanceWeight;
          final reps = set.performanceReps;
          final volume = set.performedVolume;
          final estimated1Rm = FitnessMath.estimated1RM(weight, reps);

          if (inCurrent) {
            accumulator.workingSets30d++;
            accumulator.volume30d += volume;
            final rir = set.performanceRir;
            if (rir != null && rir >= 0 && rir <= 10) {
              accumulator.rirTotal30d += rir;
              accumulator.rirCount30d++;
            }
            if (estimated1Rm != null &&
                (accumulator.bestEstimated1Rm30d == null ||
                    estimated1Rm > accumulator.bestEstimated1Rm30d!)) {
              accumulator.bestEstimated1Rm30d = estimated1Rm;
            }
          } else if (inPrevious) {
            accumulator.workingSetsPrevious30d++;
            accumulator.volumePrevious30d += volume;
            if (estimated1Rm != null &&
                (accumulator.bestEstimated1RmPrevious30d == null ||
                    estimated1Rm >
                        accumulator.bestEstimated1RmPrevious30d!)) {
              accumulator.bestEstimated1RmPrevious30d = estimated1Rm;
            }
          }

          if (weight > 0 &&
              (accumulator.bestWeight == null ||
                  weight > accumulator.bestWeight!)) {
            accumulator
              ..bestWeight = weight
              ..bestWeightAt = session.finishedAt;
          }
          if (estimated1Rm != null &&
              (accumulator.bestEstimated1Rm == null ||
                  estimated1Rm > accumulator.bestEstimated1Rm!)) {
            accumulator
              ..bestEstimated1Rm = estimated1Rm
              ..bestEstimated1RmAt = session.finishedAt;
          }
          if (volume > 0 &&
              (accumulator.bestSetVolume == null ||
                  volume > accumulator.bestSetVolume!)) {
            accumulator
              ..bestSetVolume = volume
              ..bestSetVolumeAt = session.finishedAt;
          }
        }
      }
    }

    final values = byExercise.values.toList(growable: false)
      ..sort((a, b) {
        final byDate = b.lastPerformedAt.compareTo(a.lastPerformedAt);
        if (byDate != 0) return byDate;
        return a.exerciseId.compareTo(b.exerciseId);
      });

    return List.unmodifiable(
      values.take(safeLimit).map(
            (item) => CoachExerciseProgressSummary(
              exerciseId: item.exerciseId,
              exerciseName: item.exerciseName,
              muscleGroup: item.muscleGroup,
              lastPerformedAt: item.lastPerformedAt,
              generatedAt: referenceNow,
              sessions30d: item.currentSessionIds.length,
              workingSets30d: item.workingSets30d,
              volume30d: item.volume30d,
              averageRir30d: item.rirCount30d == 0
                  ? null
                  : item.rirTotal30d / item.rirCount30d,
              sessionsPrevious30d: item.previousSessionIds.length,
              workingSetsPrevious30d: item.workingSetsPrevious30d,
              volumePrevious30d: item.volumePrevious30d,
              bestEstimated1Rm30d: item.bestEstimated1Rm30d,
              bestEstimated1RmPrevious30d:
                  item.bestEstimated1RmPrevious30d,
              bestWeight: item.bestWeight,
              bestWeightAt: item.bestWeightAt,
              bestEstimated1Rm: item.bestEstimated1Rm,
              bestEstimated1RmAt: item.bestEstimated1RmAt,
              bestSetVolume: item.bestSetVolume,
              bestSetVolumeAt: item.bestSetVolumeAt,
            ),
          ),
    );
  }

  static String _bounded(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}

class _ExerciseAccumulator {
  final String exerciseId;
  String exerciseName;
  String muscleGroup;
  DateTime lastPerformedAt;
  final Set<String> currentSessionIds = <String>{};
  final Set<String> previousSessionIds = <String>{};
  int workingSets30d = 0;
  double volume30d = 0;
  double rirTotal30d = 0;
  int rirCount30d = 0;
  int workingSetsPrevious30d = 0;
  double volumePrevious30d = 0;
  double? bestEstimated1Rm30d;
  double? bestEstimated1RmPrevious30d;
  double? bestWeight;
  DateTime? bestWeightAt;
  double? bestEstimated1Rm;
  DateTime? bestEstimated1RmAt;
  double? bestSetVolume;
  DateTime? bestSetVolumeAt;

  _ExerciseAccumulator({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.lastPerformedAt,
  });
}
