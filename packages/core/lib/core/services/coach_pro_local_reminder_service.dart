import 'package:core/core/services/local_notification_timezone.dart';
import 'package:core/features/coach_pro/domain/coach_pro_reminder_consent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Only on-device notifications. No server push or remote job is created.
/// The same three reserved IDs represent the single active coach relationship.
class CoachProLocalReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const List<int> notificationIds = [41810, 41811, 41812];
  static Future<void>? _initialization;

  static Future<void> initialize() {
    if (kIsWeb) return Future.value();
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    await LocalNotificationTimezone.ensureInitialized();
    await _plugin.initialize(settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final a = await android?.requestNotificationsPermission();
    final i = await ios?.requestPermissions(
        alert: true, badge: false, sound: false);
    return a != false && i != false;
  }

  static Future<void> cancel() async {
    if (kIsWeb) return;
    await initialize();
    for (final id in notificationIds) {
      await _plugin.cancel(id: id);
    }
  }

  static Future<void> synchronize(CoachProReminderConsent consent) async {
    if (kIsWeb) return;
    await cancel();
    if (!consent.enabled) return;
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'coach_pro_private_reminders', 'Coach Pro · Recordatorios privados',
        channelDescription: 'Recordatorios voluntarios sin datos personales',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
        enableVibration: false,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true, presentSound: false, presentBadge: false,
      ),
    );
    final now = tz.TZDateTime.now(tz.local);
    final sorted = consent.weekdays.toList()..sort();
    for (var index = 0; index < sorted.length; index++) {
      final day = sorted[index];
      final distance = (day - now.weekday + 7) % 7;
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month,
          now.day + distance, consent.hourLocal);
      if (!scheduled.isAfter(now)) {
        scheduled = tz.TZDateTime(tz.local, now.year, now.month,
            now.day + distance + 7, consent.hourLocal);
      }
      await _plugin.zonedSchedule(
        id: notificationIds[index],
        title: coachProReminderTitle,
        body: coachProReminderBody,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }
}
