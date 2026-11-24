/// Dart-only port for optional local hydration notifications.
abstract class HydrationReminderBackend {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> cancel();
  Future<bool> syncNextReminder({
    required bool enabled,
    required int currentMl,
    required int targetMl,
    required int reminderHour,
    bool requestPermissionIfNeeded = false,
  });
}

/// Core retains the historical API; Mobile owns native notifications.
class HydrationReminderService {
  static HydrationReminderBackend? _backend;

  static void installBackend(HydrationReminderBackend? backend) {
    _backend = backend;
  }

  static Future<void> initialize() =>
      _backend?.initialize() ?? Future<void>.value();

  static Future<bool> requestPermission() =>
      _backend?.requestPermission() ?? Future<bool>.value(false);

  static Future<void> cancel() =>
      _backend?.cancel() ?? Future<void>.value();

  static Future<bool> syncNextReminder({
    required bool enabled,
    required int currentMl,
    required int targetMl,
    required int reminderHour,
    bool requestPermissionIfNeeded = false,
  }) =>
      _backend?.syncNextReminder(
        enabled: enabled,
        currentMl: currentMl,
        targetMl: targetMl,
        reminderHour: reminderHour,
        requestPermissionIfNeeded: requestPermissionIfNeeded,
      ) ?? Future<bool>.value(false);
}
