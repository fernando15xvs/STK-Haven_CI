import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/progress/application/calendar_heatmap_calculator.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/presentation/providers/personal_record_provider.dart';

enum TimeFilter { week, month, threeMonths, year }

extension TimeFilterExtension on TimeFilter {
  DateTime get startDate {
    final now = DateTime.now();
    switch (this) {
      case TimeFilter.week:
        return now.subtract(const Duration(days: 7));
      case TimeFilter.month:
        return now.subtract(const Duration(days: 30));
      case TimeFilter.threeMonths:
        return now.subtract(const Duration(days: 90));
      case TimeFilter.year:
        return now.subtract(const Duration(days: 365));
    }
  }

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
  final today = DateTime(now.year, now.month, now.day);
  final calendarHeatmap = CalendarHeatmapSnapshot.fromSessions(
    allSessions,
    startDate: today.subtract(Duration(days: filter.calendarDays - 1)),
    endDate: today,
  );
  final startDate = filter.startDate;
  final periodDuration = now.difference(startDate);
  final previousStartDate = startDate.subtract(periodDuration);

  final currentPeriodSessions =
      allSessions.where((s) => s.finishedAt.isAfter(startDate)).toList();
  final previousPeriodSessions = allSessions
      .where(
        (s) => s.finishedAt.isAfter(previousStartDate) &&
            s.finishedAt.isBefore(startDate),
      )
      .toList();

  double totalVolume = 0;
  int totalSets = 0;
  int totalDurationSeconds = 0;
  final Map<DateTime, double> dailyVolume = {};
  final activeDayKeys = <String>{};

  for (final session in currentPeriodSessions) {
    totalDurationSeconds += session.durationSeconds;

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

    final dateKey = DateTime(
      session.finishedAt.year,
      session.finishedAt.month,
      session.finishedAt.day,
    );
    dailyVolume[dateKey] = (dailyVolume[dateKey] ?? 0) + sessionVolume;
    activeDayKeys.add(
      '${session.finishedAt.year}-${session.finishedAt.month}-${session.finishedAt.day}',
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

  double? volumePercentChange;
  if (previousTotalVolume > 0) {
    volumePercentChange =
        ((totalVolume - previousTotalVolume) / previousTotalVolume) * 100;
  } else if (totalVolume > 0) {
    volumePercentChange = 100.0;
  }

  final currentWorkoutCount = currentPeriodSessions.length;
  final previousWorkoutCount = previousPeriodSessions.length;
  double? workoutFrequencyPercentChange;
  if (previousWorkoutCount > 0) {
    workoutFrequencyPercentChange =
        ((currentWorkoutCount - previousWorkoutCount) / previousWorkoutCount) * 100;
  } else if (currentWorkoutCount > 0) {
    workoutFrequencyPercentChange = 100.0;
  }

  final periodDays = periodDuration.inDays <= 0 ? 1 : periodDuration.inDays;
  final workoutsPerWeek = currentWorkoutCount * 7 / periodDays;
  final averageSessionMinutes = currentWorkoutCount == 0
      ? 0.0
      : (totalDurationSeconds / 60) / currentWorkoutCount;

  final prCount = allPRs.where((pr) => pr.achievedAt.isAfter(startDate)).length;

  final chartData = dailyVolume.entries
      .map((e) => VolumeDataPoint(e.key, e.value))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  return DashboardMetrics(
    totalVolume: totalVolume,
    volumePercentChange: volumePercentChange,
    volumeChartData: chartData,
    workoutCount: currentWorkoutCount,
    totalSets: totalSets,
    totalDurationSeconds: totalDurationSeconds,
    prCount: prCount,
    activeDays: activeDayKeys.length,
    workoutsPerWeek: workoutsPerWeek,
    averageSessionMinutes: averageSessionMinutes,
    workoutFrequencyPercentChange: workoutFrequencyPercentChange,
    calendarHeatmap: calendarHeatmap,
  );
});
