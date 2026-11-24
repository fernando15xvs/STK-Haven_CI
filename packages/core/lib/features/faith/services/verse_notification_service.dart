import 'package:core/domain/models/verse.dart';
import 'package:core/features/faith/domain/verse_notification_schedule.dart';

abstract class VerseNotificationBackend {
  Future<void> initialize();
  Future<bool> requestPermissions();
  Future<bool> permissionEnabled();
  Future<void> scheduleDailyReminder();
  Future<void> schedule(VerseNotificationSchedule settings, {
    List<Verse>? verses,
    bool requireSavedConsent = false,
  });
  Future<int> pendingDailyReminderCount();
  Future<void> cancelDailyReminder();
  Future<void> schedulePreview();
  Future<void> showNotification({required String title, required String body});
}

class VerseNotificationService {
  static const legacyId = 1301;
  static const previewId = 1302;
  static const firstSlotId = 1310;
  static VerseNotificationBackend? _backend;

  static void installBackend(VerseNotificationBackend? backend) {
    _backend = backend;
  }

  static bool ownsSlot(int id) => id == legacyId ||
      (id >= firstSlotId && id < firstSlotId + VerseNotificationSchedule.maxSlots);

  static Future<void> initialize() => _backend?.initialize() ?? Future<void>.value();
  static Future<bool> requestPermissions() =>
      _backend?.requestPermissions() ?? Future<bool>.value(false);
  static Future<bool> permissionEnabled() =>
      _backend?.permissionEnabled() ?? Future<bool>.value(false);
  static Future<void> scheduleDailyReminder() =>
      _backend?.scheduleDailyReminder() ?? Future<void>.value();
  static Future<void> schedule(VerseNotificationSchedule settings, {
    List<Verse>? verses,
    bool requireSavedConsent = false,
  }) => _backend?.schedule(settings, verses: verses, requireSavedConsent: requireSavedConsent)
      ?? Future<void>.value();
  static Future<int> pendingDailyReminderCount() =>
      _backend?.pendingDailyReminderCount() ?? Future<int>.value(0);
  static Future<void> cancelDailyReminder() =>
      _backend?.cancelDailyReminder() ?? Future<void>.value();
  static Future<void> schedulePreview() =>
      _backend?.schedulePreview() ?? Future<void>.value();
  static Future<void> showNotification({required String title, required String body}) =>
      _backend?.showNotification(title: title, body: body) ?? Future<void>.value();
}
