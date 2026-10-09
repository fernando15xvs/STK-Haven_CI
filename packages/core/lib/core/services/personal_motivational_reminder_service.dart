import 'package:core/core/services/local_notification_timezone.dart';
import 'package:core/features/profile/domain/personal_reminder_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Native local scheduling: up to 48 distinct daily time slots, one per
/// interval. Each slot repeats daily and displays only ONE message.
class PersonalMotivationalReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // The previous single-message implementation used ID 42901.
  static const int legacyNotificationId = 42901;
  static const int testNotificationId = 42902;
  static const int firstDailySlotId = 42910;
  static const int maxDailySlots = 48;
  static Future<void>? _initialization;

  static Future<void> initialize() {
    if (kIsWeb) return Future<void>.value();
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    await LocalNotificationTimezone.ensureInitialized();
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
    final a = await android?.requestNotificationsPermission();
    final i = await ios?.requestPermissions(
      alert: true, badge: false, sound: true,
    );
    return a != false && i != false;
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'personal_motivational_reminders',
      'Mensajes personales',
      channelDescription: 'Avisos personales opcionales y privados',
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
    await _plugin.cancel(id: legacyNotificationId);
    await _plugin.cancel(id: testNotificationId);
    for (var i = 0; i < maxDailySlots; i++) {
      await _plugin.cancel(id: firstDailySlotId + i);
    }
  }

  /// Daily time slots repeat when app is closed (subject to OS permissions and
  /// battery restrictions). Sequence begins with message 1 at the next slot.
  /// The ordered daily round-robin starts again at the day boundary for
  /// message counts that do not divide 24 or 48.
  static Future<void> synchronize(PersonalReminderSettings settings) async {
    if (kIsWeb) return;
    await cancel();
    if (!settings.enabled) return;
    if (!settings.isValid) throw ArgumentError('Invalid reminder');
    final now = tz.TZDateTime.now(tz.local);
    final interval = settings.intervalMinutes;
    final slotCount = (24 * 60) ~/ interval;
    final currentMinutes = now.hour * 60 + now.minute;
    final firstNextSlot = (currentMinutes ~/ interval + 1) % slotCount;
    for (var slot = 0; slot < slotCount; slot++) {
      final atMinutes = slot * interval;
      var next = tz.TZDateTime(
        tz.local, now.year, now.month, now.day,
        atMinutes ~/ 60, atMinutes % 60,
      );
      if (!next.isAfter(now)) {
        next = tz.TZDateTime(
          tz.local, now.year, now.month, now.day + 1,
          atMinutes ~/ 60, atMinutes % 60,
        );
      }
      final sequence = (slot - firstNextSlot + slotCount) % slotCount;
      final item = settings.messageAt(sequence);
      await _plugin.zonedSchedule(
        id: firstDailySlotId + slot,
        title: settings.notificationTitleFor(item),
        body: settings.notificationBodyFor(item),
        scheduledDate: next,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static Future<void> showPreview(
      PersonalReminderSettings settings, PersonalReminderMessage item) async {
    if (kIsWeb) return;
    if (!item.isValid) throw ArgumentError('Invalid message');
    await initialize();
    await _plugin.show(
      id: testNotificationId,
      title: settings.notificationTitleFor(item),
      body: settings.notificationBodyFor(item),
      notificationDetails: _details,
    );
  }
}
