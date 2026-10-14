import 'package:core/core/services/workout_notification_service.dart';
import 'package:core/core/services/personal_motivational_reminder_service.dart';
import 'package:core/features/profile/data/personal_reminder_repository.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/faith/services/verse_background_service.dart';
import 'package:core/features/faith/services/verse_notification_service.dart';
import 'package:core/features/profile/data/settings_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Android-only startup services.
///
/// Keep Android plugin registration/scheduling here so the iOS entrypoint never
/// imports this layer.
Future<void> initializeAndroidPlatformServices() async {
  try {
    await VerseBackgroundService.initialize();
  } catch (_) {
    // Background fetch is optional; local notification still runs.
  }

  final settings = SettingsRepository(
    Hive.box(HiveBoxes.metadata),
  ).getSettings();
  final prefs = await SharedPreferences.getInstance();

  await prefs.setBool(
    'verse_notifications_enabled',
    settings.dailyVerseNotifications,
  );

  try {
    if (settings.dailyVerseNotifications) {
      await VerseNotificationService.scheduleDailyReminder();
      try {
        await VerseBackgroundService.scheduleDailyVerse(8, 0);
      } catch (_) {
        /* Keep native daily reminders active. */
      }
    } else {
      await VerseNotificationService.cancelDailyReminder();
      try {
        await VerseBackgroundService.cancelDailyVerse();
      } catch (_) {
        /* Best-effort cleanup. */
      }
    }
  } catch (error) {
    debugPrint('Verse reminder restoration failed: $error');
  }

  // Personal messages are private Hive data and must be re-registered after
  // app updates or a device restart. One failing service must not block others.
  try {
    final personal = PersonalReminderRepository(
      Hive.box(HiveBoxes.personalReminders),
    ).read();
    if (personal.enabled) {
      await PersonalMotivationalReminderService.synchronize(personal);
    }
  } catch (error) {
    // Reportable in settings; never erase the user's private messages.
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
