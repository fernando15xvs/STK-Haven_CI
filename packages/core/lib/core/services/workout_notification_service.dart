/// Platform-independent notification gateway retained for Core consumers.
///
/// The iOS/Android bootstrap installs a backend before the first widget is
/// mounted. Core never imports Flutter, Mobile or native notification plugins.
abstract interface class WorkoutNotificationBackend {
  Future<void> initialize();
  Future<bool> requestNotificationPermission();
  Future<void> scheduleRestTimerNotification(
    DateTime endTime, {String? workoutSessionId});
  Future<void> cancelRestTimerNotification();
  Future<bool> scheduleDailyWorkoutReminder({
    required int hour, required int minute, bool requestPermission = true});
  Future<void> scheduleUnfinishedWorkoutReminder({
    required DateTime lastActivityAt, required String workoutName});
  Future<void> cancelUnfinishedWorkoutReminders();
  Future<void> cancelDailyWorkoutReminder();
}

class _NoOpWorkoutNotificationBackend implements WorkoutNotificationBackend {
  const _NoOpWorkoutNotificationBackend();

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestNotificationPermission() async => false;
  @override
  Future<void> scheduleRestTimerNotification(
    DateTime endTime, {String? workoutSessionId}) async {}
  @override
  Future<void> cancelRestTimerNotification() async {}
  @override
  Future<bool> scheduleDailyWorkoutReminder({
    required int hour, required int minute, bool requestPermission = true,
  }) async => false;
  @override
  Future<void> scheduleUnfinishedWorkoutReminder({
    required DateTime lastActivityAt, required String workoutName,
  }) async {}
  @override
  Future<void> cancelUnfinishedWorkoutReminders() async {}
  @override
  Future<void> cancelDailyWorkoutReminder() async {}
}

/// Stable Core-facing API. No native work happens unless Mobile installs the
/// adapter, keeping paused non-Mobile consumers and tests safe.
class WorkoutNotificationService {
  WorkoutNotificationService._();
  static WorkoutNotificationBackend _backend =
      const _NoOpWorkoutNotificationBackend();

  static void installBackend(WorkoutNotificationBackend backend) {
    _backend = backend;
  }

  static Future<void> initialize() => _backend.initialize();
  static Future<bool> requestNotificationPermission() =>
      _backend.requestNotificationPermission();
  static Future<void> scheduleRestTimerNotification(
    DateTime endTime, {String? workoutSessionId}
  ) => _backend.scheduleRestTimerNotification(
    endTime, workoutSessionId: workoutSessionId);
  static Future<void> cancelRestTimerNotification() =>
      _backend.cancelRestTimerNotification();
  static Future<bool> scheduleDailyWorkoutReminder({
    required int hour, required int minute, bool requestPermission = true,
  }) => _backend.scheduleDailyWorkoutReminder(
    hour: hour, minute: minute, requestPermission: requestPermission);
  static Future<void> scheduleUnfinishedWorkoutReminder({
    required DateTime lastActivityAt, required String workoutName,
  }) => _backend.scheduleUnfinishedWorkoutReminder(
    lastActivityAt: lastActivityAt, workoutName: workoutName);
  static Future<void> cancelUnfinishedWorkoutReminders() =>
      _backend.cancelUnfinishedWorkoutReminders();
  static Future<void> cancelDailyWorkoutReminder() =>
      _backend.cancelDailyWorkoutReminder();
}
