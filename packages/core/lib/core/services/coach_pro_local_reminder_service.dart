import 'package:core/features/coach_pro/domain/coach_pro_reminder_consent.dart';

/// Pure Dart boundary for opt-in private Coach Pro reminders.
abstract class CoachProLocalReminderBackend {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> cancel();
  Future<void> synchronize(CoachProReminderConsent consent);
}

/// Core owns the public API and privacy contract, not native scheduling.
class CoachProLocalReminderService {
  static const List<int> notificationIds = [41810, 41811, 41812];
  static CoachProLocalReminderBackend? _backend;

  static void installBackend(CoachProLocalReminderBackend? backend) {
    _backend = backend;
  }

  static Future<void> initialize() =>
      _backend?.initialize() ?? Future<void>.value();

  static Future<bool> requestPermission() =>
      _backend?.requestPermission() ?? Future<bool>.value(false);

  static Future<void> cancel() =>
      _backend?.cancel() ?? Future<void>.value();

  static Future<void> synchronize(CoachProReminderConsent consent) =>
      _backend?.synchronize(consent) ?? Future<void>.value();
}
