import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final anchor = DateTime(2026, 8, 5, 17, 30);
  VolumeDataPoint point(int year, int month, int day, double volume) =>
      VolumeDataPoint(DateTime(year, month, day), volume);

  List<VolumeDataPoint> buckets(
    List<VolumeDataPoint> values,
    TimeFilter filter, {
    DateTime? start,
  }) =>
      bucketVolumeChartData(
        values,
        filter: filter,
        startDate: start ?? anchor,
      );

  test('7D/1M retain real days, gaps and sorted positions', () {
    final input = [
      point(2026, 8, 9, 500),
      point(2026, 8, 5, 200),
      point(2026, 8, 5, 350),
      point(2026, 8, 7, 100),
    ];
    for (final filter in [TimeFilter.week, TimeFilter.month]) {
      final values = buckets(input, filter);
      expect(values.length, 3);
      expect(values.map((v) => v.date),
          [DateTime(2026, 8, 5), DateTime(2026, 8, 7), DateTime(2026, 8, 9)]);
      expect(values.map((v) => v.volume), [550, 100, 500]);
      expect(values[1].date.difference(values[0].date).inDays, 2);
      expect(values[2].date.difference(values[1].date).inDays, 2);
    }
  });

  test('3M groups only observed seven-day buckets from the period anchor', () {
    final values = buckets([
      point(2026, 8, 5, 100),
      point(2026, 8, 6, 200),
      point(2026, 8, 11, 300),
      point(2026, 8, 12, 400),
      point(2026, 8, 19, 500),
      point(2026, 9, 28, 600),
    ], TimeFilter.threeMonths);
    expect(values.map((v) => v.date), [
      DateTime(2026, 8, 5),
      DateTime(2026, 8, 12),
      DateTime(2026, 8, 19),
      DateTime(2026, 9, 23),
    ]);
    expect(values.map((v) => v.volume), [600, 400, 500, 600]);
    expect(values.fold<double>(0, (sum, v) => sum + v.volume), 2100);
  });

  test('1A uses actual calendar months and keeps intermittent gaps', () {
    final values = buckets([
      point(2025, 12, 31, 1200),
      point(2026, 1, 1, 2000),
      point(2026, 1, 31, 900),
      point(2026, 4, 14, 3200),
      point(2026, 8, 1, 0),
    ], TimeFilter.year);
    expect(values.map((v) => v.date), [
      DateTime(2025, 12),
      DateTime(2026, 1),
      DateTime(2026, 4),
      DateTime(2026, 8),
    ]);
    expect(values.map((v) => v.volume), [1200, 2900, 3200, 0]);
    // Jan to Apr is a real time gap; no fabricated February/March workouts.
  });

  test('empty means no training and zero remains an observed session', () {
    expect(buckets([], TimeFilter.year), isEmpty);
    final zero = buckets([point(2026, 8, 8, 0)], TimeFilter.month);
    expect(zero.length, 1);
    expect(zero.single.volume, 0);
  });

  test('non-finite imported values do not damage chart geometry', () {
    final result = buckets([
      point(2026, 8, 5, double.nan),
      point(2026, 8, 6, double.infinity),
      point(2026, 8, 6, -20),
      point(2026, 8, 7, 15912),
    ], TimeFilter.week);
    expect(result.length, 1);
    expect(result.single.volume, 15912);
    expect(result.single.date, DateTime(2026, 8, 7));
  });

  test('timezone-hour part of anchor does not shift weekly boundaries', () {
    final start = DateTime(2026, 8, 5, 23, 59, 59);
    final result = buckets([
      point(2026, 8, 11, 4),
      point(2026, 8, 12, 5),
    ], TimeFilter.threeMonths, start: start);
    expect(result.map((v) => v.date),
        [DateTime(2026, 8, 5), DateTime(2026, 8, 12)]);
  });

  test('display contracts retain rolling 7D/1M/3M/1A sizes', () {
    expect(TimeFilter.week.calendarDays, 7);
    expect(TimeFilter.month.calendarDays, 30);
    expect(TimeFilter.threeMonths.calendarDays, 90);
    expect(TimeFilter.year.calendarDays, 365);
    expect(TimeFilter.month.startDateAt(anchor),
        anchor.subtract(const Duration(days: 30)));
  });
}
