import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/verse_notification_schedule.dart';

class VerseScheduleRepository {
  static const key = 'verse_notification_schedule_v1';

  static Future<VerseNotificationSchedule> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return const VerseNotificationSchedule();
    return VerseNotificationSchedule.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  static Future<void> save(VerseNotificationSchedule schedule) async {
    schedule.minutes;
    final saved = await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(schedule.toJson()),
    );
    if (!saved) throw StateError('No se pudieron guardar los horarios.');
  }
}
