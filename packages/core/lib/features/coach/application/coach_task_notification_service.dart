import 'package:core/domain/models/habit_task.dart';

/// Pure Dart contract for a native reminder associated with a coach task.
abstract class CoachTaskNotificationBackend {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> scheduleNextReminder(
    HabitTask task, {
    DateTime? from,
    bool requestPermissionIfNeeded = true,
  });
  Future<void> cancelReminder(String taskId);
}

/// Existing application API; scheduling and permission prompts live in Mobile.
class CoachTaskNotificationService {
  static CoachTaskNotificationBackend? _backend;

  static void installBackend(CoachTaskNotificationBackend? backend) {
    _backend = backend;
  }

  static Future<void> initialize() =>
      _backend?.initialize() ?? Future<void>.value();

  static Future<bool> requestPermission() =>
      _backend?.requestPermission() ?? Future<bool>.value(false);

  static Future<bool> scheduleNextReminder(
    HabitTask task, {
    DateTime? from,
    bool requestPermissionIfNeeded = true,
  }) =>
      _backend?.scheduleNextReminder(
        task,
        from: from,
        requestPermissionIfNeeded: requestPermissionIfNeeded,
      ) ??
      Future<bool>.value(false);

  static Future<void> cancelReminder(String taskId) =>
      _backend?.cancelReminder(taskId) ?? Future<void>.value();
}
