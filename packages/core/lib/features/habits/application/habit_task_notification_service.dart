import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/habit_schedule_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class HabitTaskNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static Future<void>? _initialization;

  static Future<void> initialize() {
    if (kIsWeb) return Future<void>.value();
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
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
      badge: true,
      sound: true,
    );
    return androidGranted != false && iosGranted != false;
  }

  static Future<bool> scheduleNext(
    HabitTask task, {
    DateTime? from,
    bool requestPermissionIfNeeded = true,
  }) async {
    if (kIsWeb || task.archived || !task.reminderEnabled) return false;
    await initialize();
    if (requestPermissionIfNeeded && !await requestPermission()) return false;

    final dueDates = HabitScheduleService.dueDates(
      task: task,
      from: from ?? DateTime.now(),
      days: 45,
    );
    if (dueDates.isEmpty) return false;

    final preferred = task.scheduledAt?.toLocal();
    final hour = preferred?.hour ?? 9;
    final minute = preferred?.minute ?? 0;
    tz.TZDateTime? scheduled;
    for (final day in dueDates) {
      final candidate = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        hour,
        minute,
      );
      if (candidate.isAfter(tz.TZDateTime.now(tz.local))) {
        scheduled = candidate;
        break;
      }
    }
    if (scheduled == null) return false;

    await _plugin.zonedSchedule(
      id: _notificationId(task.id),
      title: task.faithSpecific
          ? 'Momento de lectura · STK Haven'
          : 'Recordatorio · STK Haven',
      body: task.title,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_task_reminders',
          'Recordatorios de hábitos',
          channelDescription:
              'Recordatorios opcionales de tareas y sesiones de estudio',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:
          task.recurrence == HabitRecurrenceType.daily
              ? DateTimeComponents.time
              : null,
    );
    return true;
  }

  static Future<void> cancel(String taskId) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(id: _notificationId(taskId));
  }

  static int _notificationId(String value) {
    var hash = 0x811C9DC5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return 300000000 + (hash % 100000000);
  }
}
