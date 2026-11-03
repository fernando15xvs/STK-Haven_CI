import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reference = DateTime(2026, 11, 3, 15, 20);

  test('one deterministic cutoff for every shared Progreso filter', () {
    for (final item in [
      (filter: TimeFilter.week, days: 7, label: '7D'),
      (filter: TimeFilter.month, days: 30, label: '1M'),
      (filter: TimeFilter.threeMonths, days: 90, label: '3M'),
      (filter: TimeFilter.year, days: 365, label: '1A'),
    ]) {
      expect(item.filter.calendarDays, item.days);
      expect(item.filter.label, item.label);
      expect(
        item.filter.startDateAt(reference),
        reference.subtract(Duration(days: item.days)),
      );
      expect(
        item.filter.startDateAt(reference).add(Duration(days: item.days)),
        reference,
      );
    }
  });

  test('cutoffs do not move when the same reference instant is reused', () {
    final first = TimeFilter.month.startDateAt(reference);
    final second = TimeFilter.month.startDateAt(reference);
    expect(first, second);
  });
}
