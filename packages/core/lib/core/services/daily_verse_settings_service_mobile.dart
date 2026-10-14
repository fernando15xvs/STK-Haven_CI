import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../../features/faith/services/verse_background_service.dart';
import '../../features/faith/data/verse_schedule_repository.dart';
import '../../features/faith/services/verse_notification_service.dart';

Future<bool> configureDailyVerseNotifications(bool enable) async {
  var effectiveValue = enable;

  if (enable) {
    effectiveValue = await VerseNotificationService.requestPermissions();
  }

  final prefs = await SharedPreferences.getInstance();

  if (effectiveValue) {
    await VerseNotificationService.schedule(
      await VerseScheduleRepository.read(),
    );
    // iOS reminders are scheduled by UNUserNotificationCenter; Workmanager
    // does not guarantee a background job at 08:00 and may throw.
    if (defaultTargetPlatform != TargetPlatform.iOS && !kIsWeb) {
      try {
        await VerseBackgroundService.scheduleDailyVerse(8, 0);
      } catch (_) {
        // Native local reminder was already scheduled successfully.
      }
    }
  } else {
    await prefs.setBool('verse_notifications_enabled', false);
    await VerseNotificationService.cancelDailyReminder();
    if (defaultTargetPlatform != TargetPlatform.iOS && !kIsWeb) {
      try {
        await VerseBackgroundService.cancelDailyVerse();
      } catch (_) {
        // Native local reminder was already cancelled successfully.
      }
    }
  }

  await prefs.setBool('verse_notifications_enabled', effectiveValue);
  return effectiveValue;
}
