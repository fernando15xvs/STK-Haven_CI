import 'package:core/core/services/local_notification_timezone.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class VerseNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const int _dailyReminderId = 1301;
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
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _notificationsPlugin.initialize(settings: initSettings);
  }

  static Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    await initialize();

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    final androidGranted =
        await androidPlugin?.requestNotificationsPermission();
    final iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return androidGranted != false && iosGranted != false;
  }

  static Future<void> scheduleDailyReminder({
    int hour = 8,
    int minute = 0,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await _notificationsPlugin.cancel(id: _dailyReminderId);

    final safeHour = hour.clamp(0, 23).toInt();
    final safeMinute = minute.clamp(0, 59).toInt();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      safeHour,
      safeMinute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      id: _dailyReminderId,
      title: 'Fortaleza de hoy · STK Haven',
      body:
          'Tu versículo del día está listo. Abre STK Haven para leerlo completo.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_verse_channel_v2',
          'Fortaleza de hoy',
          channelDescription: 'Recordatorio diario del versículo en STK Haven',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    await initialize();
    await _notificationsPlugin.cancel(id: _dailyReminderId);
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await _notificationsPlugin.show(
      id: 1302,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_verse_updates',
          'Actualizaciones de versículos',
          channelDescription: 'Avisos de contenido bíblico de STK Haven',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }
}
