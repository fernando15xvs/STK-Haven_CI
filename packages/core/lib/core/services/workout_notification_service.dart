import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/workout/application/unfinished_workout_reminder_policy.dart';
import 'package:core/features/profile/data/settings_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/core/services/local_notification_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

class WorkoutNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const int _restTimerNotificationId = 999;
  static const int _restOngoingNotificationId = 998;
  static const _restActivityChannel = MethodChannel('stk_haven/rest_activity');

  static Future<void> _updateRestLiveActivity(
    DateTime endTime, String? workoutSessionId,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS ||
        workoutSessionId == null) return;
    try {
      await _restActivityChannel.invokeMethod<bool>('update', {
        'sessionId': workoutSessionId,
        'endEpochMillis': endTime.millisecondsSinceEpoch,
      });
    } catch (_) {
      // ActivityKit can be unavailable or disabled; the regular timer remains.
    }
  }

  static Future<void> _endRestLiveActivity() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _restActivityChannel.invokeMethod<bool>('end');
    } catch (_) {
      // Never block an active workout when the widget extension is absent.
    }
  }

  // A single queue prevents stale scheduled alarms from winning a rapid
  // +15s / +30s / Skip race. Generation is invalidated synchronously.
  static Future<void> _restQueue = Future<void>.value();
  static int _restGeneration = 0;

  static Future<void> _queueRest(Future<void> Function(int) action) {
    final generation = ++_restGeneration;
    final task = _restQueue.then((_) async {
      if (generation == _restGeneration) await action(generation);
    });
    _restQueue = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return task;
  }

  static const int _workoutReminderNotificationId = 1001;
  static const int _unfinishedWorkoutFirstId = 1041;
  static const int _unfinishedWorkoutFollowUpId = 1042;
  static Future<void> _unfinishedQueue = Future<void>.value();
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

  static Future<void> scheduleRestTimerNotification(
    DateTime endTime, {String? workoutSessionId}
  ) =>
      _queueRest((generation) async {
        if (kIsWeb) return;
        try {
          await initialize();
          if (generation != _restGeneration) return;
          // Live Activities use separate authorization from notifications.
          await _updateRestLiveActivity(endTime, workoutSessionId);
          if (generation != _restGeneration) return;
          if (!await requestNotificationPermission()) return;
          if (generation != _restGeneration) return;

          // Previous countdown and previous end alert never survive a time change.
          await _notificationsPlugin.cancel(id: _restOngoingNotificationId);
          await _notificationsPlugin.cancel(id: _restTimerNotificationId);
          if (generation != _restGeneration || !endTime.isAfter(DateTime.now())) return;

          final settings = SettingsRepository(
            Hive.box(HiveBoxes.metadata),
          ).getSettings();
          final sound = settings.timerSoundEnabled;
          final vibration = settings.vibrationEnabled;
          // New versioned channel: Android cannot change sound on an
          // existing channel, and user overrides must remain respected.
          final channelId = sound
              ? 'workout_rest_stk_chime_v1_${vibration ? 'vibration' : 'steady'}'
              : 'workout_rest_silent_${vibration ? 'vibration' : 'steady'}';

          // Android's native chronometer updates on its own, even with the
          // Flutter app suspended. The ongoing notification is SILENT.
          if (defaultTargetPlatform == TargetPlatform.android) {
            final remainingMs = endTime.difference(DateTime.now()).inMilliseconds;
            if (remainingMs > 0 && generation == _restGeneration) {
              await _notificationsPlugin.show(
                id: _restOngoingNotificationId,
                title: 'Descanso STK Haven',
                body: 'Tiempo restante para tu siguiente serie',
                notificationDetails: NotificationDetails(
                  android: AndroidNotificationDetails(
                    'workout_rest_ongoing_silent_v1',
                    'Descanso en curso',
                    channelDescription: 'Cuenta atrás de entrenamiento sin sonido',
                    importance: Importance.low,
                    priority: Priority.low,
                    playSound: false,
                    enableVibration: false,
                    silent: true,
                    ongoing: true,
                    autoCancel: false,
                    onlyAlertOnce: true,
                    showWhen: true,
                    usesChronometer: true,
                    chronometerCountDown: true,
                    when: endTime.millisecondsSinceEpoch,
                    timeoutAfter: remainingMs + 2000,
                    visibility: NotificationVisibility.public,
                  ),
                ),
              );
            }
          }
          if (generation != _restGeneration) return;

          final details = NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              'Temporizador de Descanso',
              channelDescription: 'Aviso único al terminar el descanso',
              importance: Importance.max,
              priority: Priority.high,
              playSound: sound,
              sound: sound
                  ? const RawResourceAndroidNotificationSound('stk_rest_complete')
                  : null,
              enableVibration: vibration,
            ),
            iOS: DarwinNotificationDetails(
              presentSound: sound,
              sound: sound ? 'stk_rest_complete.wav' : null,
              presentAlert: true,
              presentBadge: false,
            ),
          );

          final date = tz.TZDateTime.from(
            endTime.add(const Duration(seconds: 2)),
            tz.local,
          );
          if (!date.isAfter(tz.TZDateTime.now(tz.local))) return;
          final mode = await _restScheduleMode();
          if (generation != _restGeneration) return;
          await _notificationsPlugin.zonedSchedule(
            id: _restTimerNotificationId,
            title: '¡Descanso finalizado!',
            body: 'Es hora de la siguiente serie. ¡Vamos!',
            scheduledDate: date,
            notificationDetails: details,
            androidScheduleMode: mode,
          );
        } catch (_) {
          // No permission, unavailable plugin, or exact alarm restriction
          // must never interrupt the active workout or its local timer.
        }
      });

  static Future<void> cancelRestTimerNotification() =>
      _queueRest((generation) async {
        if (kIsWeb) return;
        try {
          await initialize();
          await _notificationsPlugin.cancel(id: _restOngoingNotificationId);
          await _notificationsPlugin.cancel(id: _restTimerNotificationId);
          await _endRestLiveActivity();
        } catch (_) {
          // Best-effort cleanup; serialized with any pending schedule.
        }
      });

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

  static Future<void> _serializeUnfinished(Future<void> Function() action) {
    final operation = _unfinishedQueue.then((_) => action());
    _unfinishedQueue = operation.then<void>(
      (_) {}, onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  /// Scheduled locally at last recorded edit +3h / +24h.
  /// Permission is requested only when the user enables this in settings.
  static Future<void> scheduleUnfinishedWorkoutReminder({
    required DateTime lastActivityAt,
    required String workoutName,
  }) {
    if (kIsWeb) return Future<void>.value();
    return _serializeUnfinished(() async {
      await initialize();
      await _notificationsPlugin.cancel(id: _unfinishedWorkoutFirstId);
      await _notificationsPlugin.cancel(id: _unfinishedWorkoutFollowUpId);
      final dates = UnfinishedWorkoutReminderPolicy.upcoming(
        lastActivityAt: lastActivityAt,
        now: DateTime.now(),
      );
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'unfinished_workout_channel', 'Entrenamientos pendientes',
          channelDescription: 'Avisos de sesiones sin finalizar',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      );
      final name = workoutName.trim().isEmpty
          ? 'Tu entrenamiento' : workoutName.trim();
      for (var i = 0; i < dates.length; i++) {
        await _notificationsPlugin.zonedSchedule(
          id: i == 0 ? _unfinishedWorkoutFirstId : _unfinishedWorkoutFollowUpId,
          title: i == 0
              ? 'Entrenamiento pendiente' : '¿Finalizaste tu entrenamiento?',
          body: '$name sigue sin finalizar. Abre STK Haven para revisarlo.',
          scheduledDate: tz.TZDateTime.from(dates[i], tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    });
  }

  static Future<void> cancelUnfinishedWorkoutReminders() {
    if (kIsWeb) return Future<void>.value();
    return _serializeUnfinished(() async {
      await initialize();
      await _notificationsPlugin.cancel(id: _unfinishedWorkoutFirstId);
      await _notificationsPlugin.cancel(id: _unfinishedWorkoutFollowUpId);
    });
  }

  static Future<void> cancelDailyWorkoutReminder() async {
    if (kIsWeb) return;
    await initialize();
    await _notificationsPlugin.cancel(id: _workoutReminderNotificationId);
  }
}
