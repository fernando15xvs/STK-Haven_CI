import 'package:core/features/profile/domain/personal_reminder_settings.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// This box is not included in STK Haven's backup/cloud export.
class PersonalReminderRepository {
  final Box<dynamic> box;
  static const String storageKey = 'personal_reminder_v1';

  const PersonalReminderRepository(this.box);

  PersonalReminderSettings read() =>
      PersonalReminderSettings.fromJson(box.get(storageKey));

  Future<void> write(PersonalReminderSettings settings) {
    if (!settings.isValid) {
      throw ArgumentError('Invalid personal reminder settings');
    }
    return box.put(storageKey, settings.toJson());
  }

  Future<void> clear() => box.delete(storageKey);
}
