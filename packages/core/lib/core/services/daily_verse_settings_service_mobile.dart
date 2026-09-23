import 'package:shared_preferences/shared_preferences.dart';

import '../../features/faith/services/verse_background_service.dart';
import '../../features/faith/services/verse_notification_service.dart';

Future<bool> configureDailyVerseNotifications(bool enable) async {
  var effectiveValue = enable;

  if (enable) {
    effectiveValue = await VerseNotificationService.requestPermissions();
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('verse_notifications_enabled', effectiveValue);

  if (effectiveValue) {
    await VerseBackgroundService.scheduleDailyVerse(8, 0);
  } else {
    await VerseBackgroundService.cancelDailyVerse();
  }

  return effectiveValue;
}
