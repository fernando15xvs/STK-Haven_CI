import 'workout_reminder_settings_service_stub.dart'
    if (dart.library.io) 'workout_reminder_settings_service_mobile.dart'
    as implementation;

Future<bool> configureWorkoutReminder({
  required bool enabled,
  required int hour,
  required int minute,
}) {
  return implementation.configureWorkoutReminder(
    enabled: enabled,
    hour: hour,
    minute: minute,
  );
}
