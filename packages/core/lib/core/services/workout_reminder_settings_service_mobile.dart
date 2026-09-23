import 'workout_notification_service.dart';

Future<bool> configureWorkoutReminder({
  required bool enabled,
  required int hour,
  required int minute,
}) async {
  if (!enabled) {
    await WorkoutNotificationService.cancelDailyWorkoutReminder();
    return false;
  }

  return WorkoutNotificationService.scheduleDailyWorkoutReminder(
    hour: hour,
    minute: minute,
  );
}
