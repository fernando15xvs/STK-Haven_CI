import 'package:core/domain/models/step_goal_preferences.dart';

/// Dart-only port for optional local step-goal notifications.
abstract class StepGoalReminderBackend {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> cancel();
  Future<bool> syncToday({
    required StepGoalPreferences preferences,
    required int currentSteps,
    required DateTime? lastSyncedAt,
    bool requestPermissionIfNeeded = false,
  });
}

class StepGoalReminderService {
  static StepGoalReminderBackend? _backend;

  static void installBackend(StepGoalReminderBackend? backend) {
    _backend = backend;
  }

  static Future<void> initialize() =>
      _backend?.initialize() ?? Future<void>.value();

  static Future<bool> requestPermission() =>
      _backend?.requestPermission() ?? Future<bool>.value(false);

  static Future<void> cancel() =>
      _backend?.cancel() ?? Future<void>.value();

  static Future<bool> syncToday({
    required StepGoalPreferences preferences,
    required int currentSteps,
    required DateTime? lastSyncedAt,
    bool requestPermissionIfNeeded = false,
  }) =>
      _backend?.syncToday(
        preferences: preferences,
        currentSteps: currentSteps,
        lastSyncedAt: lastSyncedAt,
        requestPermissionIfNeeded: requestPermissionIfNeeded,
      ) ?? Future<bool>.value(false);
}
