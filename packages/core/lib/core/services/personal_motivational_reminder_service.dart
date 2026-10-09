import 'package:core/features/profile/domain/personal_reminder_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Uses a single platform repeating notification, not a queue of dozens of
/// pending notifications. OS battery rules may delay delivery.
class PersonalMotivationalReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const int notificationId = 42901;
  static const int testNotificationId = 42902;
  static Future<void>? _initialization;

  static Future<void> initialize() {
    if (kIsWeb) return Future<void>.value();
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
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
      alert: true, badge: false, sound: true,
    );
    return androidGranted != false && iosGranted != false;
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'personal_motivational_reminders',
      'Mensajes personales',
      channelDescription:
          'Recordatorios personales voluntarios, cada 30 o 60 minutos',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: false,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: false,
      presentBadge: false,
    ),
  );

  static Future<void> cancel() async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(id: notificationId);
    await _plugin.cancel(id: testNotificationId);
  }

  /// Caller must explicitly request OS permissions before enabling.
  /// A repeating interval survives the app being closed where supported.
  static Future<void> synchronize(PersonalReminderSettings settings) async {
    if (kIsWeb) return;
    await cancel();
    if (!settings.enabled) return;
    if (!settings.isValid) throw ArgumentError('Invalid reminder');
    await _plugin.periodicallyShowWithDuration(
      id: notificationId,
      title: 'STK Haven · Para ti',
      body: settings.notificationBody,
      repeatDurationInterval: Duration(minutes: settings.intervalMinutes),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Preview is user-triggered and never starts the recurring schedule.
  static Future<void> showPreview(PersonalReminderSettings settings) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.show(
      id: testNotificationId,
      title: 'STK Haven · Para ti',
      body: settings.notificationBody,
      notificationDetails: _details,
    );
  }
}
