import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/habit_schedule_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class CoachTaskNotificationService {
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

  static Future<bool> scheduleNextReminder(
    HabitTask task, {
    DateTime? from,
    bool requestPermissionIfNeeded = true,
  }) async {
    if (kIsWeb || task.archived || !task.reminderEnabled) return false;
    await initialize();
    if (requestPermissionIfNeeded && !await requestPermission()) return false;

    final now = DateTime.now();
    final searchFrom = from ?? now;
    final dueDates = HabitScheduleService.dueDates(
      task: task,
      from: searchFrom,
      days: 45,
    );
    if (dueDates.isEmpty) return false;

    final preferred = task.scheduledAt?.toLocal();
    final hour = preferred == null || (preferred.hour == 0 && preferred.minute == 0)
        ? 9
        : preferred.hour;
    final minute = preferred == null ? 0 : preferred.minute;

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
      title: 'Tarea asignada · STK Haven',
      body: task.title,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'coach_task_reminders',
          'Recordatorios de tareas',
          channelDescription:
              'Recordatorios opcionales de tareas asignadas en STK Haven',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return true;
  }

  static Future<void> cancelReminder(String taskId) async {
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
    return 200000000 + (hash % 100000000);
  }
}
