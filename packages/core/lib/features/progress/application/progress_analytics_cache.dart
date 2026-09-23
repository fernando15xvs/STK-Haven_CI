import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:core/features/workout/application/workout_history_index.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProgressPeriod {
  final DateTime? from;
  final DateTime? to;
  final int maxChartPoints;

  const ProgressPeriod({
    this.from,
    this.to,
    this.maxChartPoints = 120,
  });

  @override
  bool operator ==(Object other) =>
      other is ProgressPeriod &&
      other.from == from &&
      other.to == to &&
      other.maxChartPoints == maxChartPoints;

  @override
  int get hashCode => Object.hash(from, to, maxChartPoints);
}

class ExerciseAnalyticsRequest {
  final String exerciseId;
  final ProgressPeriod period;

  const ExerciseAnalyticsRequest(
    this.exerciseId, {
    this.period = const ProgressPeriod(),
  });

  @override
  bool operator ==(Object other) =>
      other is ExerciseAnalyticsRequest &&
      other.exerciseId == exerciseId &&
      other.period == period;

  @override
  int get hashCode => Object.hash(exerciseId, period);
}

/// Cache lifetime equals one immutable WorkoutHistoryIndex revision. When Hive
/// history changes, workoutHistoryIndexProvider creates a new index object and
/// Riverpod disposes this cache instance, guaranteeing stale metrics are not
/// retained after create/edit/restore operations.
class ProgressAnalyticsCache {
  ProgressAnalyticsCache(this._index);

  final WorkoutHistoryIndex _index;
  final Map<ExerciseAnalyticsRequest, ExerciseProgressTrend> _cache = {};

  ExerciseProgressTrend trend(ExerciseAnalyticsRequest request) {
    return _cache.putIfAbsent(request, () {
      final sessions = _uniqueSessions(
        _index.exerciseOccurrences(
          request.exerciseId,
          from: request.period.from,
          to: request.period.to,
        ),
      );
      return ExerciseProgressCalculator.calculateTrend(
        sessions,
        request.exerciseId,
        from: request.period.from,
        to: request.period.to,
        maxChartPoints: request.period.maxChartPoints,
      );
    });
  }

  int get cachedEntryCount => _cache.length;

  static List<WorkoutSession> _uniqueSessions(
    Iterable<WorkoutExerciseOccurrence> occurrences,
  ) {
    final seen = <String>{};
    final sessions = <WorkoutSession>[];
    for (final occurrence in occurrences) {
      if (seen.add(occurrence.session.id)) sessions.add(occurrence.session);
    }
    return sessions;
  }
}

final progressAnalyticsCacheProvider = Provider<ProgressAnalyticsCache>((ref) {
  final index = ref.watch(workoutHistoryIndexProvider);
  return ProgressAnalyticsCache(index);
});

final exerciseProgressTrendProvider =
    Provider.family<ExerciseProgressTrend, ExerciseAnalyticsRequest>((ref, request) {
  final cache = ref.watch(progressAnalyticsCacheProvider);
  return cache.trend(request);
});
