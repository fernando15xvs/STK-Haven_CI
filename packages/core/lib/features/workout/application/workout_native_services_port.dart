/// Cross-platform contract for workout OS effects. No Flutter or UI types.
///
/// Core decides *when* a rest completes and which settings are enabled.
/// The mobile layer implements notifications, lifecycle, native sound and haptics.
abstract interface class WorkoutNativeServices {
  Future<void> scheduleRestTimerNotification(
    DateTime endsAt, {
    String? workoutSessionId,
  });

  Future<void> cancelRestTimerNotification();

  Future<void> scheduleUnfinishedWorkoutReminder({
    required DateTime lastActivityAt,
    required String workoutName,
  });

  Future<void> cancelUnfinishedWorkoutReminders();

  /// Must suppress local effects while backgrounded, leaving the OS reminder.
  /// Fire-and-forget, matching the original timer callback behavior.
  void playRestCompletionCueIfForeground({
    required bool soundEnabled,
    required bool vibrationEnabled,
  });
}

/// Safe for tests and a paused Web consumer that has no mobile platform.
///
/// The native bootstrap MUST inject a real implementation; a missing override
/// should never cause a workout to fail to load or modify persisted data.
class NoOpWorkoutNativeServices implements WorkoutNativeServices {
  const NoOpWorkoutNativeServices();

  @override
  Future<void> scheduleRestTimerNotification(
    DateTime endsAt, {
    String? workoutSessionId,
  }) async {}

  @override
  Future<void> cancelRestTimerNotification() async {}

  @override
  Future<void> scheduleUnfinishedWorkoutReminder({
    required DateTime lastActivityAt,
    required String workoutName,
  }) async {}

  @override
  Future<void> cancelUnfinishedWorkoutReminders() async {}

  @override
  void playRestCompletionCueIfForeground({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) {}
}
