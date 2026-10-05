import 'package:core/domain/models/step_goal_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class StepGoalReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const List<int> _notificationIds = <int>[1201, 1202];
  static Future<void>? _initialization;

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
    for (final id in _notificationIds) {
      await _plugin.cancel(id: id);
    }
  }

  static Future<bool> syncToday({
    required StepGoalPreferences preferences,
    required int currentSteps,
    required DateTime? lastSyncedAt,
    bool requestPermissionIfNeeded = false,
  }) async {
    if (kIsWeb) return false;
    await initialize();
    await cancel();

    if (!preferences.reminderEnabled) return true;

    if (requestPermissionIfNeeded && !await requestPermission()) {
      return false;
    }

    if (currentSteps >= preferences.targetSteps) {
      return true;
    }

    final slots = preferences.reminderCadence == StepReminderCadence.gentle
        ? const <(int, int)>[(20, 0)]
        : const <(int, int)>[(17, 30), (20, 30)];

    final localNow = DateTime.now();
    final missing =
        (preferences.targetSteps - currentSteps).clamp(0, 50000).toInt();
    final lastSyncText = _lastSyncText(lastSyncedAt);
    var scheduledCount = 0;

    for (var index = 0; index < slots.length; index += 1) {
      final slot = slots[index];
      final localTarget = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
        slot.$1,
        slot.$2,
      );
      if (!localTarget.isAfter(localNow)) continue;

      await _schedule(
        id: _notificationIds[index],
        scheduled: _asAbsoluteZonedTime(localTarget, localNow),
        targetSteps: preferences.targetSteps,
        missingSteps: missing,
        lastSyncText: lastSyncText,
      );
      scheduledCount += 1;
    }

    if (scheduledCount == 0) {
      final first = slots.first;
      final tomorrow = localNow.add(const Duration(days: 1));
      final localTarget = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        first.$1,
        first.$2,
      );
      await _schedule(
        id: _notificationIds.first,
        scheduled: _asAbsoluteZonedTime(localTarget, localNow),
        targetSteps: preferences.targetSteps,
        missingSteps: null,
        lastSyncText: null,
      );
    }

    return true;
  }

  static tz.TZDateTime _asAbsoluteZonedTime(
    DateTime localTarget,
    DateTime localNow,
  ) {
    final delay = localTarget.difference(localNow);
    return tz.TZDateTime.now(tz.local).add(delay);
  }

  static Future<void> _schedule({
    required int id,
    required tz.TZDateTime scheduled,
    required int targetSteps,
    required int? missingSteps,
    required String? lastSyncText,
  }) async {
    const android = AndroidNotificationDetails(
      'step_goal_reminders',
      'Metas de pasos',
      channelDescription:
          'Recordatorios opcionales para revisar tu meta diaria de pasos',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    final body = missingSteps == null
        ? 'Tu meta de hoy es $targetSteps pasos. Revisa cómo vas cuando puedas.'
        : 'Te faltan $missingSteps pasos para tu meta de $targetSteps'
            '${lastSyncText == null ? '.' : ' · $lastSyncText.'}';

    await _plugin.zonedSchedule(
      id: id,
      title: 'Pasos · STK Haven',
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: android,
        iOS: ios,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static String? _lastSyncText(DateTime? lastSyncedAt) {
    if (lastSyncedAt == null) return null;
    final hour = lastSyncedAt.hour.toString().padLeft(2, '0');
    final minute = lastSyncedAt.minute.toString().padLeft(2, '0');
    return 'según la última sincronización de $hour:$minute';
  }
}
