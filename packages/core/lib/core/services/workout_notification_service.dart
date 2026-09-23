import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/profile/data/settings_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class WorkoutNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const int _restTimerNotificationId = 999;
  static const int _workoutReminderNotificationId = 1001;
  static Future<void>? _initialization;

  /// Idempotent/lazy initialization.
  ///
  /// Mobile startup defers non-critical plugins until after the first frame,
  /// but an already-active workout may resume and request a rest notification
  /// before that deferred initializer runs. Every public operation therefore
  /// ensures the plugin is ready without requiring startup to block.
  static Future<void> initialize() {
    if (kIsWeb) return Future<void>.value();
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    tz.initializeTimeZones();
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

  static Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;
    await initialize();
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    final androidGranted = await androidPlugin?.requestNotificationsPermission();
    final iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return androidGranted != false && iosGranted != false;
  }

  static Future<AndroidScheduleMode> _restScheduleMode() async {
    await initialize();
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final exactAlarmGranted = await androidPlugin?.requestExactAlarmsPermission();
    return exactAlarmGranted == false
        ? AndroidScheduleMode.inexactAllowWhileIdle
        : AndroidScheduleMode.exactAllowWhileIdle;
  }

  static Future<void> scheduleRestTimerNotification(DateTime endTime) async {
    if (kIsWeb) return;
    await initialize();
    if (!await requestNotificationPermission()) return;

    final settings = SettingsRepository(
      Hive.box(HiveBoxes.metadata),
    ).getSettings();
    final sound = settings.timerSoundEnabled;
    final vibration = settings.vibrationEnabled;

    // Android notification-channel capabilities are effectively persistent, so
    // preference combinations use distinct stable channel IDs. This prevents a
    // previously-created loud channel from ignoring a later silent preference.
    final channelId =
        'workout_rest_${sound ? 'sound' : 'silent'}_${vibration ? 'vibration' : 'steady'}';
    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Temporizador de Descanso',
      channelDescription: 'Avisos de fin de descanso en el entrenamiento',
      importance: Importance.max,
      priority: Priority.high,
      playSound: sound,
      enableVibration: vibration,
    );
    final iosDetails = DarwinNotificationDetails(
      presentSound: sound,
      presentAlert: true,
      presentBadge: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledDate = tz.TZDateTime.from(endTime, tz.local);
    if (scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      await _notificationsPlugin.zonedSchedule(
        id: _restTimerNotificationId,
        title: '¡Descanso finalizado!',
        body: 'Es hora de la siguiente serie. ¡Vamos!',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: await _restScheduleMode(),
      );
    }
  }

  static Future<void> cancelRestTimerNotification() async {
    if (kIsWeb) return;
    await initialize();
    await _notificationsPlugin.cancel(id: _restTimerNotificationId);
  }

  static Future<bool> scheduleDailyWorkoutReminder({
    required int hour,
    required int minute,
    bool requestPermission = true,
  }) async {
    if (kIsWeb) return false;
    await initialize();
    if (requestPermission && !await requestNotificationPermission()) return false;

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

    const androidDetails = AndroidNotificationDetails(
      'workout_reminder_channel',
      'Recordatorios de entrenamiento',
      channelDescription: 'Recordatorio diario configurable para entrenar',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
    );

    await _notificationsPlugin.zonedSchedule(
      id: _workoutReminderNotificationId,
      title: 'STK Haven',
      body: 'Tu entrenamiento de hoy te está esperando.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  static Future<void> cancelDailyWorkoutReminder() async {
    if (kIsWeb) return;
    await initialize();
    await _notificationsPlugin.cancel(id: _workoutReminderNotificationId);
  }
}
