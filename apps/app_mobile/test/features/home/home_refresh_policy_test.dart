import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/home/application/home_refresh_policy.dart';

void main() {
  test('midnight changes the calendar day even within the same hour', () {
    final before = DateTime(2026, 11, 13, 23, 59);
    final after = DateTime(2026, 11, 14, 0, 1);
    expect(HomeRefreshPolicy.sameLocalDay(before, after), isFalse);
    expect(HomeRefreshPolicy.needsHeaderUpdate(before, after), isTrue);
  });

  test('greeting changes at noon and 18:00, not every minute', () {
    final morning = DateTime(2026, 11, 13, 11, 59);
    final noon = DateTime(2026, 11, 13, 12);
    final afternoon = DateTime(2026, 11, 13, 17, 59);
    final evening = DateTime(2026, 11, 13, 18);
    expect(HomeRefreshPolicy.needsHeaderUpdate(morning, noon), isTrue);
    expect(HomeRefreshPolicy.needsHeaderUpdate(noon, afternoon), isFalse);
    expect(HomeRefreshPolicy.needsHeaderUpdate(afternoon, evening), isTrue);
    expect(HomeRefreshPolicy.needsHeaderUpdate(
      DateTime(2026, 11, 13, 14, 10),
      DateTime(2026, 11, 13, 14, 11),
    ), isFalse);
  });

  test('performance savings reduces polling frequency', () {
    expect(HomeRefreshPolicy.stepRefreshInterval(savings: false),
        const Duration(minutes: 1));
    expect(HomeRefreshPolicy.stepRefreshInterval(savings: true),
        const Duration(minutes: 5));
  });

  test('only visible and foreground surfaces can poll the sensor', () {
    for (final visible in [true, false]) {
      for (final resumed in [true, false]) {
        expect(
          HomeRefreshPolicy.canPoll(visible: visible, appResumed: resumed),
          visible && resumed,
        );
      }
    }
  });
}
