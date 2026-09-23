import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:core/features/faith/data/bible_database.dart';
import 'package:core/features/faith/data/bible_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'verse_notification_service.dart';

const String dailyVerseTask = 'dailyVerseTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == dailyVerseTask) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final isEnabled =
            prefs.getBool('verse_notifications_enabled') ?? true;

        if (!isEnabled) return true;

        final repo = BibleRepository(BibleDatabase.instance);
        final currentMood = prefs.getString('current_mood') ?? 'General';
        final newVerse = await repo.getRandomVerse(mood: currentMood);

        if (newVerse != null) {
          await prefs.setString('saved_verse', newVerse.text);
          await prefs.setString('saved_reference', newVerse.reference);

          // Background tasks execute in a separate isolate, so initialize the
          // local notification plugin in this isolate before displaying.
          await VerseNotificationService.initialize();
          await VerseNotificationService.showNotification(
            title: 'Fortaleza: ${newVerse.reference}',
            body: newVerse.text,
          );
        }
      } catch (_) {
        return false;
      }
    }
    return true;
  });
}

class VerseBackgroundService {
  static Future<void> initialize() async {
    if (kIsWeb) return;
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> scheduleDailyVerse(int hour, int minute) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final initialDelay = scheduledTime.difference(now);

    await Workmanager().cancelByUniqueName(dailyVerseTask);
    await Workmanager().registerPeriodicTask(
      dailyVerseTask,
      dailyVerseTask,
      frequency: const Duration(days: 1),
      initialDelay: initialDelay,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
    );
  }

  static Future<void> cancelDailyVerse() async {
    if (kIsWeb) return;
    await Workmanager().cancelByUniqueName(dailyVerseTask);
  }
}
