import 'dart:math' as math;

import 'package:core/core/utils/fitness_math.dart';
import 'package:core/domain/models/workout_session.dart';

class ExerciseProgressPoint {
  final DateTime date;
  final double value;

  const ExerciseProgressPoint({required this.date, required this.value});
}

class ExerciseSessionPerformance {
  final String sessionId;
  final DateTime date;
  final String? routineId;
  final String routineName;
  final double bestWeight;
  final int bestReps;
  final double? averageRir;
  final double estimated1RM;
  final double volume;
  final int completedWorkingSets;
  final double? leftEstimated1RM;
  final double? rightEstimated1RM;
  final double? leftVolume;
  final double? rightVolume;

  const ExerciseSessionPerformance({
    required this.sessionId,
    required this.date,
    required this.routineId,
    required this.routineName,
    required this.bestWeight,
    required this.bestReps,
    required this.averageRir,
    required this.estimated1RM,
    required this.volume,
    required this.completedWorkingSets,
    this.leftEstimated1RM,
    this.rightEstimated1RM,
    this.leftVolume,
    this.rightVolume,
  });

  bool get hasUnilateralDetail =>
      leftEstimated1RM != null ||
      rightEstimated1RM != null ||
      leftVolume != null ||
      rightVolume != null;
}

class ExerciseSessionComparison {
  final ExerciseSessionPerformance latest;
  final ExerciseSessionPerformance previous;

  const ExerciseSessionComparison({
    required this.latest,
    required this.previous,
  });

  double get weightDelta => latest.bestWeight - previous.bestWeight;
  int get repsDelta => latest.bestReps - previous.bestReps;
  double? get rirDelta => latest.averageRir == null || previous.averageRir == null
      ? null
      : latest.averageRir! - previous.averageRir!;
  double get estimated1RmDelta => latest.estimated1RM - previous.estimated1RM;
  double get volumeDelta => latest.volume - previous.volume;
}

class ExerciseProgressTrend {
  final double current1RM;
  final double? absoluteChange30Days;
  final double? percentChange30Days;
  final List<ExerciseProgressPoint> history1RM;
  final List<ExerciseProgressPoint> historyWeight;
  final List<ExerciseProgressPoint> historyReps;
  final List<ExerciseProgressPoint> historyRir;
  final List<ExerciseSessionPerformance> sessions;
  final int sessionCount;
  final int completedWorkSets;
  final double totalVolume;
  final double maxWeight;
  final double bestSetVolume;
  final double lastSessionVolume;
  final DateTime? lastPerformedAt;

  const ExerciseProgressTrend({
    required this.current1RM,
    this.absoluteChange30Days,
    this.percentChange30Days,
    required this.history1RM,
    this.historyWeight = const [],
    this.historyReps = const [],
    this.historyRir = const [],
    this.sessions = const [],
    this.sessionCount = 0,
    this.completedWorkSets = 0,
    this.totalVolume = 0,
    this.maxWeight = 0,
    this.bestSetVolume = 0,
    this.lastSessionVolume = 0,
    this.lastPerformedAt,
  });

  bool get hasRecordedWork => sessionCount > 0;
  ExerciseSessionPerformance? get latestSession =>
      sessions.isEmpty ? null : sessions.last;
  ExerciseSessionPerformance? get previousSession =>
      sessions.length < 2 ? null : sessions[sessions.length - 2];

  ExerciseSessionComparison? get latestComparison {
    final latest = latestSession;
    final previous = previousSession;
    if (latest == null || previous == null) return null;
    return ExerciseSessionComparison(latest: latest, previous: previous);
  }

  /// Informational signal only. It means the last three e1RM observations are
  /// within a narrow two-percent band; it is not a diagnosis nor an automatic
  /// reason to deload.
  bool get hasPlateauSignal {
    final valid = sessions.where((item) => item.estimated1RM > 0).toList();
    if (valid.length < 3) return false;
    final recent = valid.sublist(valid.length - 3);
    final values = recent.map((item) => item.estimated1RM).toList();
    final high = values.reduce(math.max);
    final low = values.reduce(math.min);
    if (high <= 0) return false;
    return ((high - low) / high) <= 0.02;
  }

  /// Absolute latest e1RM difference between sides as a percentage of the
  /// stronger side. Presented as neutral information, never as a body judgment.
  double? get latestSideDifferencePercent {
    final latest = latestSession;
    final left = latest?.leftEstimated1RM;
    final right = latest?.rightEstimated1RM;
    if (left == null || right == null || left <= 0 || right <= 0) return null;
    final strongest = math.max(left, right);
    return ((left - right).abs() / strongest) * 100;
  }
}

class ExerciseProgressCalculator {
  /// Global exercise dashboard keyed by [exerciseId]. Routine membership is
  /// context only. Aggregate metrics use all filtered sessions while chart
  /// collections are downsampled independently.
  static ExerciseProgressTrend calculateTrend(
    List<WorkoutSession> history,
    String exerciseId, {
    DateTime? from,
    DateTime? to,
    int maxChartPoints = 120,
  }) {
    final performances = <ExerciseSessionPerformance>[];
    var completedWorkSets = 0;
    var totalVolume = 0.0;
    var maxWeight = 0.0;
    var bestSetVolume = 0.0;

    for (final session in history) {
      if (from != null && session.startedAt.isBefore(from)) continue;
      if (to != null && !session.startedAt.isBefore(to)) continue;

      var max1RmInSession = 0.0;
      var bestWeightInSession = 0.0;
      var repsAtBestWeight = 0;
      var sessionVolume = 0.0;
      var sessionCompletedSets = 0;
      var rirTotal = 0.0;
      var rirCount = 0;
      double? leftBest1Rm;
      double? rightBest1Rm;
      var leftRawVolume = 0.0;
      var rightRawVolume = 0.0;
      var hasLeftDetail = false;
      var hasRightDetail = false;

      for (final exercise in session.exercises.where(
        (item) => item.exerciseId == exerciseId,
      )) {
        for (final set in exercise.sets) {
          if (!set.completed || set.setType != WorkoutSetType.working) continue;

          sessionCompletedSets++;
          completedWorkSets++;
          final setVolume = set.performedVolume;
          sessionVolume += setVolume;
          totalVolume += setVolume;

          final performanceWeight = set.performanceWeight;
          final performanceReps = set.performanceReps;
          if (performanceWeight > maxWeight) maxWeight = performanceWeight;
          if (performanceWeight > bestWeightInSession ||
              (performanceWeight == bestWeightInSession &&
                  performanceReps > repsAtBestWeight)) {
            bestWeightInSession = performanceWeight;
            repsAtBestWeight = performanceReps;
          }
          if (setVolume > bestSetVolume) bestSetVolume = setVolume;

          final rir = set.performanceRir;
          if (rir != null) {
            rirTotal += rir;
            rirCount++;
          }

          final estimated = FitnessMath.estimated1RM(
            performanceWeight,
            performanceReps,
          );
          if (estimated != null && estimated > max1RmInSession) {
            max1RmInSession = estimated;
          }

          if (set.hasDetailedSideData) {
            if (set.leftCompleted) {
              hasLeftDetail = true;
              final weight = set.weightForSide(WorkoutSide.left);
              final reps = set.repsForSide(WorkoutSide.left);
              leftRawVolume += weight * reps;
              final estimate = FitnessMath.estimated1RM(weight, reps);
              if (estimate != null &&
                  (leftBest1Rm == null || estimate > leftBest1Rm)) {
                leftBest1Rm = estimate;
              }
            }
            if (set.rightCompleted) {
              hasRightDetail = true;
              final weight = set.weightForSide(WorkoutSide.right);
              final reps = set.repsForSide(WorkoutSide.right);
              rightRawVolume += weight * reps;
              final estimate = FitnessMath.estimated1RM(weight, reps);
              if (estimate != null &&
                  (rightBest1Rm == null || estimate > rightBest1Rm)) {
                rightBest1Rm = estimate;
              }
            }
          }
        }
      }

      if (sessionCompletedSets == 0) continue;
      performances.add(
        ExerciseSessionPerformance(
          sessionId: session.id,
          date: session.startedAt,
          routineId: session.routineId,
          routineName: session.routineNameSnapshot,
          bestWeight: bestWeightInSession,
          bestReps: repsAtBestWeight,
          averageRir: rirCount == 0 ? null : rirTotal / rirCount,
          estimated1RM: max1RmInSession,
          volume: sessionVolume,
          completedWorkingSets: sessionCompletedSets,
          leftEstimated1RM: hasLeftDetail ? leftBest1Rm : null,
          rightEstimated1RM: hasRightDetail ? rightBest1Rm : null,
          leftVolume: hasLeftDetail ? leftRawVolume : null,
          rightVolume: hasRightDetail ? rightRawVolume : null,
        ),
      );
    }

    performances.sort((a, b) => a.date.compareTo(b.date));
    if (performances.isEmpty) {
      return ExerciseProgressTrend(
        current1RM: 0,
        history1RM: const [],
        completedWorkSets: completedWorkSets,
        totalVolume: totalVolume,
        maxWeight: maxWeight,
        bestSetVolume: bestSetVolume,
      );
    }

    final current1Rm = performances.last.estimated1RM;
    final latestDate = performances.last.date;
    final thirtyDaysBeforeLatest = latestDate.subtract(const Duration(days: 30));
    ExerciseSessionPerformance? baseline;
    for (var index = performances.length - 2; index >= 0; index--) {
      final candidate = performances[index];
      if (!candidate.date.isAfter(thirtyDaysBeforeLatest)) {
        baseline = candidate;
        break;
      }
    }

    double? absoluteChange30Days;
    double? percentChange30Days;
    if (baseline != null && baseline.estimated1RM > 0) {
      absoluteChange30Days = current1Rm - baseline.estimated1RM;
      percentChange30Days =
          (absoluteChange30Days / baseline.estimated1RM) * 100;
    }

    final all1Rm = performances
        .where((item) => item.estimated1RM > 0)
        .map(
          (item) => ExerciseProgressPoint(
            date: item.date,
            value: item.estimated1RM,
          ),
        )
        .toList(growable: false);
    final allWeight = performances
        .map(
          (item) => ExerciseProgressPoint(
            date: item.date,
            value: item.bestWeight,
          ),
        )
        .toList(growable: false);
    final allReps = performances
        .map(
          (item) => ExerciseProgressPoint(
            date: item.date,
            value: item.bestReps.toDouble(),
          ),
        )
        .toList(growable: false);
    final allRir = performances
        .where((item) => item.averageRir != null)
        .map(
          (item) => ExerciseProgressPoint(
            date: item.date,
            value: item.averageRir!,
          ),
        )
        .toList(growable: false);

    return ExerciseProgressTrend(
      current1RM: current1Rm,
      absoluteChange30Days: absoluteChange30Days,
      percentChange30Days: percentChange30Days,
      history1RM: _downsample(all1Rm, maxChartPoints),
      historyWeight: _downsample(allWeight, maxChartPoints),
      historyReps: _downsample(allReps, maxChartPoints),
      historyRir: _downsample(allRir, maxChartPoints),
      sessions: List.unmodifiable(performances),
      sessionCount: performances.length,
      completedWorkSets: completedWorkSets,
      totalVolume: totalVolume,
      maxWeight: maxWeight,
      bestSetVolume: bestSetVolume,
      lastSessionVolume: performances.last.volume,
      lastPerformedAt: performances.last.date,
    );
  }

  static List<ExerciseProgressPoint> _downsample(
    List<ExerciseProgressPoint> points,
    int maxPoints,
  ) {
    if (maxPoints <= 0 || points.length <= maxPoints) return points;
    if (maxPoints == 1) return [points.last];

    final result = <ExerciseProgressPoint>[points.first];
    final interiorSlots = maxPoints - 2;
    if (interiorSlots > 0) {
      final step = (points.length - 1) / (maxPoints - 1);
      for (var slot = 1; slot <= interiorSlots; slot++) {
        final index = (slot * step)
            .round()
            .clamp(1, points.length - 2)
            .toInt();
        result.add(points[index]);
      }
    }
    result.add(points.last);
    return result;
  }
}
