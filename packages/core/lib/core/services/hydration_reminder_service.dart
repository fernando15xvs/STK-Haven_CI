import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:core/core/services/local_notification_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

class HydrationReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const int _notificationId = 1102;
  static Future<void>? _initialization;

  static Future<void> initialize() {
    if (kIsWeb) return Future<void>.value();
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    await LocalNotificationTimezone.ensureInitialized();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final androidGranted = await android?.requestNotificationsPermission();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: false,
      sound: true,
    );
    return androidGranted != false && iosGranted != false;
  }

  static Future<void> cancel() async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(id: _notificationId);
  }

  static Future<bool> syncNextReminder({
    required bool enabled,
    required int currentMl,
    required int targetMl,
    required int reminderHour,
    bool requestPermissionIfNeeded = false,
  }) async {
    if (kIsWeb) return false;
    await initialize();
    await _plugin.cancel(id: _notificationId);
    if (!enabled) return true;

    if (requestPermissionIfNeeded && !await requestPermission()) {
      return false;
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminderHour.clamp(6, 22).toInt(),
    );

    var body = _bodyFor(currentMl: currentMl, targetMl: targetMl);
    if (!scheduled.isAfter(now) || currentMl >= targetMl) {
      scheduled = scheduled.add(const Duration(days: 1));
      body = 'Recuerda registrar tu hidratación de hoy.';
    }

    const android = AndroidNotificationDetails(
      'hydration_reminder_channel',
      'Recordatorios de hidratación',
      channelDescription:
          'Avisos configurables para revisar tu hidratación diaria',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Hidratación · STK Haven',
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: android,
        iOS: ios,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return true;
  }

  static String _bodyFor({
    required int currentMl,
    required int targetMl,
  }) {
    final missing = (targetMl - currentMl).clamp(0, 5000);
    if (missing <= 0) {
      return 'Meta de hidratación registrada por hoy.';
    }
    return 'Te faltan $missing ml para tu meta personal de hoy.';
  }
}
