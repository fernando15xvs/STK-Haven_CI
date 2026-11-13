import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/progress/application/calendar_heatmap_calculator.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/presentation/providers/personal_record_provider.dart';

/// A frequency/calendar training day needs evidence of completed working
/// exercise, not merely an imported or empty historical row. A partially
/// finalized workout qualifies once work exists, without granting completion
/// rewards or changing its persisted state. Bodyweight work (0 kg) qualifies.
bool hasRecordedTrainingActivity(WorkoutSession session) {
  return session.exercises.any(
    (exercise) => exercise.sets.any(
      (set) =>
          set.setType == WorkoutSetType.working &&
          set.completed &&
          set.performanceReps > 0,
    ),
  );
}

/// A calendar day can include records up to the observation instant, not
/// later today. Preserves the historical row while excluding future-dated
/// imports from current active days, frequency and comparisons.
bool isRecordedTrainingActivityAsOf(WorkoutSession session, DateTime now) =>
    !session.finishedAt.isAfter(now) && hasRecordedTrainingActivity(session);

/// Date-window contract shared with the heatmap: no future finish dates.
/// A partial session with recorded work still belongs to its finish date;
/// reward/program completion is governed separately by WorkoutNotifier.
bool isSessionInMetricsPeriod(
  WorkoutSession session, {
  required DateTime startDate,
  required DateTime endDate,
}) =>
    session.finishedAt.isAfter(startDate) &&
    !session.finishedAt.isAfter(endDate);

/// A pure average over the session cohort supplied by the caller.
/// Progreso passes only effective training activity in its finish-time window.
/// Incomplete entries are retained, with rewards/program progression handled
/// elsewhere. This summary does not attempt to estimate active exercise time.
class RecordedDurationSummary {
  const RecordedDurationSummary({
    required this.sessionCount,
    required this.totalDurationSeconds,
  });

  final int sessionCount;
  final int totalDurationSeconds;

  double get averageMinutes => sessionCount == 0
      ? 0
      : totalDurationSeconds / 60 / sessionCount;
}

/// Pure calculation for reproducible partial, imported and long-session tests.
/// Callers apply their date window first; no stored duration is altered.
RecordedDurationSummary summarizeRecordedDurations(
  Iterable<WorkoutSession> recordedSessions,
) {
  var count = 0;
  var seconds = 0;
  for (final session in recordedSessions) {
    count++;
    seconds += session.durationSeconds;
  }
  return RecordedDurationSummary(
    sessionCount: count,
    totalDurationSeconds: seconds,
  );
}

/// Compares complete periods; no percentage is meaningful without a
/// positive previous-period baseline. Null means "sin referencia".
double? periodPercentChange(double current, double previous) {
  if (!current.isFinite || !previous.isFinite || previous <= 0) {
    return null;
  }
  return (current - previous) / previous * 100;
}

enum TimeFilter { week, month, threeMonths, year }

extension TimeFilterExtension on TimeFilter {
  /// A deterministic rolling window: the same reference instant produces
  /// identical cutoffs in all Progreso calculations.
  DateTime startDateAt(DateTime now) =>
      now.subtract(Duration(days: calendarDays));

  DateTime get startDate => startDateAt(DateTime.now());

  String get label {
    switch (this) {
      case TimeFilter.week:
        return '7D';
      case TimeFilter.month:
        return '1M';
      case TimeFilter.threeMonths:
        return '3M';
      case TimeFilter.year:
        return '1A';
    }
  }

  int get calendarDays {
    switch (this) {
      case TimeFilter.week:
        return 7;
      case TimeFilter.month:
        return 30;
      case TimeFilter.threeMonths:
        return 90;
      case TimeFilter.year:
        return 365;
    }
  }
}

class VolumeDataPoint {
  final DateTime date;
  final double volume;

  const VolumeDataPoint(this.date, this.volume);
}

/// Groups only *observed* training volumes for the requested period.
///
/// 7D and 1M keep each local calendar day; 3M groups into seven-day
/// windows anchored to the selected period's first day; 1A uses calendar
/// months. Missing dates are gaps, NOT fabricated zero-workout sessions.
/// All volume values are stored in kg and converted only by the UI.
List<VolumeDataPoint> bucketVolumeChartData(
  Iterable<VolumeDataPoint> observedDailyVolumes, {
  required TimeFilter filter,
  required DateTime startDate,
}) {
  final firstDayUtc =
      DateTime.utc(startDate.year, startDate.month, startDate.day);
  final buckets = <DateTime, double>{};
  for (final point in observedDailyVolumes) {
    // Negative / non-finite training volume is not a chartable observation.
    // Leave source history untouched, do not manufacture a replacement point.
    if (!point.volume.isFinite || point.volume < 0) continue;
    final day = DateTime(point.date.year, point.date.month, point.date.day);
    final bucket = switch (filter) {
      TimeFilter.week || TimeFilter.month => day,
      TimeFilter.threeMonths =>
        _weeklyVolumeBucket(day, firstDayUtc, startDate),
      TimeFilter.year => DateTime(day.year, day.month),
    };
    buckets.update(
      bucket,
      (current) => current + point.volume,
      ifAbsent: () => point.volume,
    );
  }
  return [
    for (final entry in (buckets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key))))
      VolumeDataPoint(entry.key, entry.value),
  ];
}

DateTime _weeklyVolumeBucket(
  DateTime localDay,
  DateTime firstDayUtc,
  DateTime startDate,
) {
  // Compare calendar-day values in UTC to prevent local DST changes from
  // moving a session into the wrong seven-day bucket.
  final utcDay = DateTime.utc(
    localDay.year,
    localDay.month,
    localDay.day,
  );
  final index = utcDay.difference(firstDayUtc).inDays ~/ 7;
  return DateTime(
    startDate.year,
    startDate.month,
    startDate.day + index * 7,
  );
}

class DashboardMetrics {
  final double totalVolume;
  final double? volumePercentChange;
  final List<VolumeDataPoint> volumeChartData;
  final int workoutCount;
  final int totalSets;
  final int totalDurationSeconds;
  final int prCount;
  final int activeDays;
  final double workoutsPerWeek;
  final double averageSessionMinutes;
  final double? workoutFrequencyPercentChange;
  final CalendarHeatmapSnapshot calendarHeatmap;

  const DashboardMetrics({
    required this.totalVolume,
    required this.volumePercentChange,
    required this.volumeChartData,
    required this.workoutCount,
    required this.totalSets,
    required this.totalDurationSeconds,
    required this.prCount,
    required this.activeDays,
    required this.workoutsPerWeek,
    required this.averageSessionMinutes,
    required this.workoutFrequencyPercentChange,
    required this.calendarHeatmap,
  });
}

class TimeFilterNotifier extends Notifier<TimeFilter> {
  @override
  TimeFilter build() => TimeFilter.month;

  void setFilter(TimeFilter filter) {
    state = filter;
  }
}

final timeFilterProvider =
    NotifierProvider<TimeFilterNotifier, TimeFilter>(TimeFilterNotifier.new);

final progressMetricsProvider = Provider<DashboardMetrics>((ref) {
  final filter = ref.watch(timeFilterProvider);
  final allSessions = ref.watch(workoutHistoryProvider);
  final allPRs = ref.watch(personalRecordRepositoryProvider).getAllPRs();
  final now = DateTime.now();
  // The same eligibility gate feeds the calendar and all numeric metrics;
  // future timestamps from imports are not counted even later today.
  final activitySessions = allSessions
      .where((session) => isRecordedTrainingActivityAsOf(session, now))
      .toList();
  final today = DateTime(now.year, now.month, now.day);
  final calendarHeatmap = CalendarHeatmapSnapshot.fromSessions(
    activitySessions,
    startDate: today.subtract(Duration(days: filter.calendarDays - 1)),
    endDate: today,
  );
  final startDate = filter.startDateAt(now);
  final periodDuration = now.difference(startDate);
  final previousStartDate = startDate.subtract(periodDuration);

  final currentPeriodSessions = activitySessions
      .where((session) => isSessionInMetricsPeriod(
            session,
            startDate: startDate,
            endDate: now,
          ))
      .toList();
  final previousPeriodSessions = activitySessions
      .where(
        (s) => s.finishedAt.isAfter(previousStartDate) &&
            s.finishedAt.isBefore(startDate),
      )
      .toList();

  double totalVolume = 0;
  int totalSets = 0;
  final recordedDuration = summarizeRecordedDurations(currentPeriodSessions);
  final Map<DateTime, double> dailyVolume = {};
  final activeDayKeys = <String>{};

  for (final session in currentPeriodSessions) {
    double sessionVolume = 0;
    for (final ex in session.exercises) {
      for (final set in ex.sets) {
        if (set.completed && !set.warmup) {
          totalSets++;
          sessionVolume += set.performedVolume;
        }
      }
    }

    totalVolume += sessionVolume;

    // Keep numeric active days and volume buckets on the same local finish
    // date as the heatmap and Home's completed-session summary.
    final finished = session.finishedAt.toLocal();
    final dateKey = DateTime(finished.year, finished.month, finished.day);
    dailyVolume[dateKey] = (dailyVolume[dateKey] ?? 0) + sessionVolume;
    activeDayKeys.add(
      '${finished.year}-${finished.month}-${finished.day}',
    );
  }

  double previousTotalVolume = 0;
  for (final session in previousPeriodSessions) {
    for (final ex in session.exercises) {
      for (final set in ex.sets) {
        if (set.completed && !set.warmup) {
          previousTotalVolume += set.performedVolume;
        }
      }
    }
  }

  // A zero/unknown baseline cannot be described as +100% growth.
  final volumePercentChange =
      periodPercentChange(totalVolume, previousTotalVolume);

  final currentWorkoutCount = currentPeriodSessions.length;
  final previousWorkoutCount = previousPeriodSessions.length;
  final workoutFrequencyPercentChange = periodPercentChange(
    currentWorkoutCount.toDouble(),
    previousWorkoutCount.toDouble(),
  );

  final periodDays = periodDuration.inDays <= 0 ? 1 : periodDuration.inDays;
  final workoutsPerWeek = currentWorkoutCount * 7 / periodDays;
  final averageSessionMinutes = recordedDuration.averageMinutes;

  final prCount = allPRs.where((pr) => pr.achievedAt.isAfter(startDate)).length;

  final chartData = bucketVolumeChartData(
    dailyVolume.entries.map((e) => VolumeDataPoint(e.key, e.value)),
    filter: filter,
    startDate: startDate,
  );

  return DashboardMetrics(
    totalVolume: totalVolume,
    volumePercentChange: volumePercentChange,
    volumeChartData: chartData,
    workoutCount: currentWorkoutCount,
    totalSets: totalSets,
    totalDurationSeconds: recordedDuration.totalDurationSeconds,
    prCount: prCount,
    activeDays: activeDayKeys.length,
    workoutsPerWeek: workoutsPerWeek,
    averageSessionMinutes: averageSessionMinutes,
    workoutFrequencyPercentChange: workoutFrequencyPercentChange,
    calendarHeatmap: calendarHeatmap,
  );
});
