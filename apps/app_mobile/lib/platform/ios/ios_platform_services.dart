import 'package:core/core/services/workout_notification_service.dart';
import 'package:core/core/services/personal_motivational_reminder_service.dart';
import 'package:core/features/profile/data/personal_reminder_repository.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/faith/services/verse_notification_service.dart';
import 'package:core/features/profile/data/settings_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// iOS-only startup services.
///
/// Keep Apple-specific startup isolated from Android so iOS can evolve its
/// notification/background policy independently.
Future<void> initializeIosPlatformServices() async {
  // Workmanager is not a reliable notification scheduler on iOS.
  // The OS-native repeating local notification remains the source of truth.

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
    } else {
      await VerseNotificationService.cancelDailyReminder();
    }
  } catch (error) {
    // A missing Bible reminder must never disable the user's personal
    // reminder rotation or the workout notifications.
    debugPrint('Daily verse reminder scheduling failed: $error');
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
    debugPrint('Personal reminder restoration failed: $error');
    // Never erase the user's private messages on a scheduling failure.
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
