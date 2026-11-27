import 'dart:async';

import 'package:core/core/config/supabase_config.dart';
import 'package:core/database/hive/hive_database.dart';
import 'package:core/core/services/supabase_client_gateway.dart';
import 'package:core/core/services/workout_notification_service.dart';
import 'package:core/core/services/hydration_reminder_service.dart';
import 'package:core/core/services/step_goal_reminder_service.dart';
import 'package:core/core/services/coach_pro_local_reminder_service.dart';
import 'package:core/core/services/backup_file_service.dart';
import 'package:core/features/profile/application/data_export_service.dart';
import 'package:core/core/services/daily_verse_settings_service.dart';
import 'package:core/features/faith/services/verse_background_service.dart';
import 'package:core/features/faith/services/verse_widget_sync.dart';
import 'package:core/features/faith/data/bible_database.dart';
import '../../platform/storage/mobile_core_preferences.dart';
import 'package:core/core/services/personal_motivational_reminder_service.dart';
import 'package:core/features/faith/services/verse_notification_service.dart';
import 'package:core/features/progress/services/measurement_reminder_service.dart';
import 'package:core/features/coach/application/coach_task_notification_service.dart';
import 'package:core/features/habits/application/habit_task_notification_service.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/stk_haven_app.dart';
import '../../platform/workout/mobile_workout_native_services.dart';
import '../../platform/workout/mobile_workout_notification_service.dart';
import '../../platform/reminders/mobile_hydration_reminder_service.dart';
import '../../platform/reminders/mobile_step_goal_reminder_service.dart';
import '../../platform/reminders/mobile_coach_pro_local_reminder_service.dart';
import '../../platform/reminders/mobile_coach_task_notification_service.dart';
import '../../platform/reminders/mobile_habit_task_notification_service.dart';
import '../../platform/reminders/mobile_verse_notification_service.dart';
import '../../platform/reminders/mobile_personal_motivational_reminder_service.dart';
import '../../platform/reminders/mobile_measurement_reminder_service.dart';
import '../../platform/faith/mobile_verse_widget_backend.dart';
import '../../platform/faith/mobile_verse_background_service.dart';
import '../../platform/faith/mobile_daily_verse_settings_service.dart';
import '../../platform/faith/mobile_bible_database.dart';
import '../../platform/files/mobile_backup_file_service.dart';
import '../../platform/files/mobile_data_export_service.dart';

typedef PlatformServicesInitializer = Future<void> Function();

/// Shared bootstrap for both native mobile targets.
///
/// The caller injects only the services for the target platform so Android and
/// iOS do not need to import one another's startup layers.
Future<void> bootstrapMobileApp({
  required PlatformServicesInitializer initializePlatformServices,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  installMobileCorePreferences();
  await initializeDateFormatting('es', null);
  Intl.defaultLocale = 'es';

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  CoreSupabaseClient.installClient(Supabase.instance.client);

  await Hive.initFlutter(); // platform initialization remains in Mobile
  await HiveDatabase.init();

  // One native backend for Core settings and Mobile workout effects.
  // Install it before mounting providers or restoring platform reminders.
  WorkoutNotificationService.installBackend(
    const MobileWorkoutNotificationBackend(),
  );
  HydrationReminderService.installBackend(
    const MobileHydrationReminderBackend(),
  );
  StepGoalReminderService.installBackend(
    const MobileStepGoalReminderBackend(),
  );
  CoachProLocalReminderService.installBackend(
    const MobileCoachProLocalReminderBackend(),
  );
  CoachTaskNotificationService.installBackend(
    const MobileCoachTaskNotificationBackend(),
  );
  HabitTaskNotificationService.installBackend(
    const MobileHabitTaskNotificationBackend(),
  );
  VerseNotificationService.installBackend(const MobileVerseNotificationBackend());
  PersonalMotivationalReminderService.installBackend(
    const MobilePersonalMotivationalReminderBackend(),
  );
  MeasurementReminderService.installBackend(const MobileMeasurementReminderBackend());
  BibleDatabase.installBackend(MobileBibleDatabase.instance);
  VerseWidgetSync.installBackend(const MobileVerseWidgetBackend());
  VerseBackgroundService.installBackend(const MobileVerseBackgroundBackend());
  DailyVerseSettingsService.installBackend(const MobileDailyVerseSettingsBackend());
  BackupFileService.installBackend(const MobileBackupFileBackend());
  DataExportService.installBackend(const MobileDataExportBackend());

  // Initialise OS lock-screen and notification controls before creating a player.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.Fernando_S_ac.gym_tracker.motivation',
      androidNotificationChannelName: 'STK Motivation',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('STK Motivation background initialization failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        workoutNativeServicesProvider.overrideWithValue(
          const MobileWorkoutNativeServices(),
        ),
      ],
      child: const MyApp(),
    ),
  );

  // Native notification/background plugins are useful but not required for the
  // first interaction. Give the first screen a short idle window before plugin
  // registration and scheduling work begins.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      _initializePlatformServicesBestEffort(initializePlatformServices),
    );
  });
}

Future<void> _initializePlatformServicesBestEffort(
  PlatformServicesInitializer initializePlatformServices,
) async {
  await Future<void>.delayed(const Duration(seconds: 2));
  try {
    await initializePlatformServices();
  } catch (error, stackTrace) {
    debugPrint('Platform services initialization skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
