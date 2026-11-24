import 'package:core/features/profile/domain/personal_reminder_settings.dart';

abstract class PersonalMotivationalReminderBackend {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<int> pendingSlots();
  Future<void> cancel();
  Future<void> synchronize(PersonalReminderSettings settings);
  Future<void> showPreview(PersonalReminderSettings settings, PersonalReminderMessage item);
}

class PersonalMotivationalReminderService {
  static const int legacyNotificationId = 42901;
  static const int testNotificationId = 42902;
  static const int firstDailySlotId = 42910;
  static const int maxDailySlots = 48;
  static PersonalMotivationalReminderBackend? _backend;

  static void installBackend(PersonalMotivationalReminderBackend? backend) {
    _backend = backend;
  }

  static Future<void> initialize() => _backend?.initialize() ?? Future<void>.value();
  static Future<bool> requestPermission() =>
      _backend?.requestPermission() ?? Future<bool>.value(false);
  static Future<int> pendingSlots() =>
      _backend?.pendingSlots() ?? Future<int>.value(0);
  static int expectedSlots(PersonalReminderSettings settings) =>
      settings.enabled ? (24 * 60) ~/ settings.intervalMinutes : 0;
  static Future<void> cancel() => _backend?.cancel() ?? Future<void>.value();
  static Future<void> synchronize(PersonalReminderSettings settings) =>
      _backend?.synchronize(settings) ?? Future<void>.value();
  static Future<void> showPreview(
    PersonalReminderSettings settings, PersonalReminderMessage item,
  ) => _backend?.showPreview(settings, item) ?? Future<void>.value();
}
