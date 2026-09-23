import 'package:core/core/services/workout_notification_service.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/faith/services/verse_background_service.dart';
import 'package:core/features/faith/services/verse_notification_service.dart';
import 'package:core/features/profile/data/settings_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android-only startup services.
///
/// Keep Android plugin registration/scheduling here so the iOS entrypoint never
/// imports this layer.
Future<void> initializeAndroidPlatformServices() async {
  await VerseNotificationService.initialize();
  await WorkoutNotificationService.initialize();
  await VerseBackgroundService.initialize();

  final settings = SettingsRepository(
    Hive.box(HiveBoxes.metadata),
  ).getSettings();
  final prefs = await SharedPreferences.getInstance();

  await prefs.setBool(
    'verse_notifications_enabled',
    settings.dailyVerseNotifications,
  );

  if (settings.dailyVerseNotifications) {
    await VerseBackgroundService.scheduleDailyVerse(8, 0);
  } else {
    await VerseBackgroundService.cancelDailyVerse();
  }

  if (settings.workoutRemindersEnabled) {
    await WorkoutNotificationService.scheduleDailyWorkoutReminder(
      hour: settings.workoutReminderHour,
      minute: settings.workoutReminderMinute,
      requestPermission: false,
    );
  } else {
    await WorkoutNotificationService.cancelDailyWorkoutReminder();
  }
}
