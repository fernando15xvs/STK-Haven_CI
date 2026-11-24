import 'package:core/domain/models/habit_task.dart';

/// Pure Dart contract for on-device habit notifications.
abstract class HabitTaskNotificationBackend {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> scheduleNext(
    HabitTask task, {
    DateTime? from,
    bool requestPermissionIfNeeded = true,
  });
  Future<void> cancel(String taskId);
}

/// Keep callers independent of Flutter and the notification plugin.
class HabitTaskNotificationService {
  static HabitTaskNotificationBackend? _backend;

  static void installBackend(HabitTaskNotificationBackend? backend) {
    _backend = backend;
  }

  static Future<void> initialize() =>
      _backend?.initialize() ?? Future<void>.value();

  static Future<bool> requestPermission() =>
      _backend?.requestPermission() ?? Future<bool>.value(false);

  static Future<bool> scheduleNext(
    HabitTask task, {
    DateTime? from,
    bool requestPermissionIfNeeded = true,
  }) =>
      _backend?.scheduleNext(
        task,
        from: from,
        requestPermissionIfNeeded: requestPermissionIfNeeded,
      ) ??
      Future<bool>.value(false);

  static Future<void> cancel(String taskId) =>
      _backend?.cancel(taskId) ?? Future<void>.value();
}
