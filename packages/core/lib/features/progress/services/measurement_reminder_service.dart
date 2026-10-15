import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:core/core/services/local_notification_timezone.dart';
import 'package:core/domain/models/body_measurement.dart';
import '../domain/measurement_progress.dart';

class MeasurementReminderSettings {
  final bool enabled;
  final int months;
  final int hour;
  final int minute;
  const MeasurementReminderSettings({
    this.enabled = false,
    this.months = 1,
    this.hour = 9,
    this.minute = 0,
  });
  Map<String, Object> toJson() => {
    'enabled': enabled,
    'months': months,
    'hour': hour,
    'minute': minute,
  };
  factory MeasurementReminderSettings.fromJson(Map<String, dynamic> json) =>
      MeasurementReminderSettings(
        enabled: json['enabled'] == true,
        months: ((json['months'] as num?)?.toInt() ?? 1).clamp(1, 3).toInt(),
        hour: ((json['hour'] as num?)?.toInt() ?? 9).clamp(0, 23).toInt(),
        minute: ((json['minute'] as num?)?.toInt() ?? 0).clamp(0, 59).toInt(),
      );
  DateTime? dueDate(List<BodyMeasurement> measurements) {
    if (measurements.isEmpty) return null;
    final latest = measurements.reduce(
      (a, b) => a.date.isAfter(b.date) ? a : b,
    );
    return nextMeasurementDate(latest.date, months, hour: hour, minute: minute);
  }
}

/// One reminder per measurement cycle, replaced after recording new data.
/// No periodic background process or server access is needed.
class MeasurementReminderService {
  static const notificationId = 1601;
  static const _key = 'measurement_reminder_v1';
  static const _scheduledKey = 'measurement_reminder_scheduled_v1';
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _initialization;
  static Future<void> _queue = Future.value();

  static Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<MeasurementReminderSettings> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const MeasurementReminderSettings();
    try {
      return MeasurementReminderSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const MeasurementReminderSettings();
    }
  }

  static Future<void> _initialize() async {
    try {
      await (_initialization ??= () async {
        await LocalNotificationTimezone.ensureInitialized();
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestSoundPermission: false,
              requestBadgePermission: false,
            ),
          ),
        );
      }());
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  static Future<bool> _permission({bool request = false}) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (request)
        await ios?.requestPermissions(alert: true, sound: true, badge: false);
      final status = await ios?.checkPermissions();
      return status?.isEnabled == true && status?.isAlertEnabled == true;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (request) await android?.requestNotificationsPermission();
    return await android?.areNotificationsEnabled() ?? false;
  }

  static Future<void> configure(
    MeasurementReminderSettings settings,
    List<BodyMeasurement> measurements,
  ) => _serialize(() async {
    if (kIsWeb)
      throw StateError(
        'Los avisos de medidas están disponibles en Android e iPhone.',
      );
    if (settings.months < 1 ||
        settings.months > 3 ||
        settings.hour < 0 ||
        settings.hour > 23 ||
        settings.minute < 0 ||
        settings.minute > 59) {
      throw ArgumentError('Horario de medidas no válido');
    }
    await _initialize();
    if (settings.enabled && !await _permission(request: true)) {
      throw StateError(
        'Activa las notificaciones de STK Haven en los ajustes del teléfono.',
      );
    }
    await _synchronize(settings, measurements);
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(settings.toJson()),
    );
  });

  static Future<void> synchronize(List<BodyMeasurement> measurements) =>
      _serialize(() async {
        if (kIsWeb) return;
        final settings = await read();
        await _initialize();
        await _synchronize(settings, measurements);
      });

  static Future<void> _synchronize(
    MeasurementReminderSettings settings,
    List<BodyMeasurement> measurements,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final due = settings.dueDate(measurements);
    if (!settings.enabled || due == null) {
      await _plugin.cancel(id: notificationId);
      await prefs.remove(_scheduledKey);
      return;
    }
    if (!await _permission())
      throw StateError('El permiso de notificaciones está desactivado.');
    final now = tz.TZDateTime.now(tz.local);
    final at = tz.TZDateTime(
      tz.local,
      due.year,
      due.month,
      due.day,
      due.hour,
      due.minute,
    );
    final fingerprint = '${at.toIso8601String()}/${settings.months}';
    // Do not re-send an overdue reminder on every app launch or old-entry edit.
    if (prefs.getString(_scheduledKey) == fingerprint && !at.isAfter(now))
      return;
    final pending = await _plugin.pendingNotificationRequests();
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        pending.where((p) => p.id != notificationId).length >= 60) {
      throw StateError(
        'No queda espacio para otro aviso. Reduce otros recordatorios y vuelve a intentarlo.',
      );
    }
    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'STK Haven · Actualiza tus medidas',
      body: 'Registra tus nuevas medidas para seguir tu evolución.',
      scheduledDate: at.isAfter(now) ? at : now.add(const Duration(minutes: 1)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'body_measurements_v1',
          'Medidas corporales',
          channelDescription: 'Recordatorio para actualizar tus medidas',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    if (!(await _plugin.pendingNotificationRequests()).any(
      (p) => p.id == notificationId,
    )) {
      throw StateError(
        'El teléfono no conservó el recordatorio. Vuelve a intentarlo.',
      );
    }
    await prefs.setString(_scheduledKey, fingerprint);
  }
}
