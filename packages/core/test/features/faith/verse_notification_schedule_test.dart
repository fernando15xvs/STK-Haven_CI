import 'package:core/features/faith/domain/verse_notification_schedule.dart';
import 'package:core/features/faith/data/verse_schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'legacy users retain only 08:00 until explicitly changing hours',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect((await VerseScheduleRepository.read()).minutes, [480]);
    },
  );
  test(
    'interval is anchored to start and never passes the end of the window',
    () {
      expect(
        const VerseNotificationSchedule(
          mode: VerseScheduleMode.interval,
          intervalMinutes: 120,
          startMinute: 495,
          endMinute: 1000,
        ).minutes,
        [495, 615, 735, 855, 975],
      );
    },
  );
  test('multiple hours are sorted and deduplicated, including midnight', () {
    expect(
      const VerseNotificationSchedule(times: [1200, 0, 480, 480]).minutes,
      [0, 480, 1200],
    );
  });
  test('invalid inputs cannot silently create a different schedule', () {
    for (final schedule in [
      const VerseNotificationSchedule(times: []),
      const VerseNotificationSchedule(times: [-1]),
      const VerseNotificationSchedule(times: [1440]),
      const VerseNotificationSchedule(
        mode: VerseScheduleMode.interval,
        intervalMinutes: 0,
      ),
      const VerseNotificationSchedule(
        mode: VerseScheduleMode.interval,
        startMinute: 1200,
        endMinute: 480,
      ),
    ]) {
      expect(() => schedule.minutes, throwsFormatException);
    }
  });
  test('full day has bounded slots', () {
    expect(
      const VerseNotificationSchedule(
        mode: VerseScheduleMode.interval,
        intervalMinutes: 30,
        startMinute: 0,
        endMinute: 1439,
      ).minutes.length,
      48,
    );
  });
  test('hours persist without enabling notifications', () async {
    SharedPreferences.setMockInitialValues({
      'verse_notifications_enabled': false,
    });
    const schedule = VerseNotificationSchedule(times: [510, 900, 1260]);
    await VerseScheduleRepository.save(schedule);
    expect((await VerseScheduleRepository.read()).minutes, [510, 900, 1260]);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'verse_notifications_enabled',
      ),
      false,
    );
  });
}
