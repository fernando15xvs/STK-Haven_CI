import 'package:core/core/services/local_notification_timezone.dart';
import 'package:core/domain/models/verse.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/bible_database.dart';
import '../data/bible_repository.dart';
import '../data/verse_schedule_repository.dart';
import '../domain/verse_notification_schedule.dart';

class VerseNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const legacyId = 1301;
  static const previewId = 1302;
  static const firstSlotId = 1310;
  static Future<void>? _initialization;
  static Future<void> _queue = Future<void>.value();

  static bool ownsSlot(int id) =>
      id == legacyId ||
      (id >= firstSlotId &&
          id < firstSlotId + VerseNotificationSchedule.maxSlots);

  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await (_initialization ??= _initialize());
    } catch (_) {
      _initialization =
          null; // A transient plugin failure must remain retryable.
      rethrow;
    }
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

  static Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  static Future<bool> permissionEnabled() async {
    if (kIsWeb) return false;
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final options = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return options?.isEnabled == true && options?.isAlertEnabled == true;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        false;
  }

  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_verse_channel_v2',
      'Versículos',
      channelDescription: 'Versículos en los horarios que elijas',
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
  );

  /// Serialize replacement/cancellation so rapid settings changes cannot leave
  /// a partly enabled schedule. Other notification families are never cancelled.
  static Future<void> _serialize(Future<void> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  /// Compatibility entry point: existing consent keeps its old 08:00 schedule
  /// until the user explicitly saves different hours.
  static Future<void> scheduleDailyReminder() async {
    await schedule(
      await VerseScheduleRepository.read(),
      requireSavedConsent: true,
    );
  }

  static Future<void> schedule(
    VerseNotificationSchedule settings, {
    List<Verse>? verses,
    bool requireSavedConsent = false,
  }) => _serialize(() async {
    if (kIsWeb) return;
    await initialize();
    if (requireSavedConsent &&
        (await SharedPreferences.getInstance()).getBool(
              'verse_notifications_enabled',
            ) !=
            true) {
      return;
    }
    final minutes = settings.minutes;
    if (!await permissionEnabled()) {
      throw StateError(
        'Activa las notificaciones y los avisos de STK Haven en los ajustes del teléfono.',
      );
    }
    final pending = await _plugin.pendingNotificationRequests();
    final otherCount = pending
        .where((item) => !ownsSlot(item.id) && item.id != previewId)
        .length;
    // Leave headroom for workout/water/step reminders. iOS keeps only 64.
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        otherCount + minutes.length > 60) {
      throw StateError(
        'No hay espacio para tantos avisos. Elige menos horas o reduce la frecuencia de tus mensajes personales.',
      );
    }
    final content =
        verses ??
        await BibleRepository(
          BibleDatabase.instance,
        ).getNotificationVerses(minutes.length);
    if (content.length < minutes.length ||
        content.map((v) => v.reference).toSet().length < minutes.length ||
        content.any((v) => v.text.trim().isEmpty)) {
      throw StateError(
        'Abre la Biblia y espera a que termine de descargarse antes de activar estos avisos.',
      );
    }
    // All preflight checks run before touching a working schedule.
    await _cancelSlots();
    try {
      final now = tz.TZDateTime.now(tz.local);
      for (var i = 0; i < minutes.length; i++) {
        final at = minutes[i];
        var next = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          at ~/ 60,
          at % 60,
        );
        if (!next.isAfter(now)) {
          next = tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day + 1,
            at ~/ 60,
            at % 60,
          );
        }
        final verse = content[i];
        await _plugin.zonedSchedule(
          id: firstSlotId + i,
          title: '${verse.reference} · STK Haven',
          body: verse.text,
          scheduledDate: next,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      if (await pendingDailyReminderCount() != minutes.length) {
        throw StateError(
          'El teléfono no conservó todos los avisos. Reduce la frecuencia y vuelve a guardar.',
        );
      }
    } catch (_) {
      await _cancelSlots();
      rethrow;
    }
  });

  static Future<int> pendingDailyReminderCount() async {
    if (kIsWeb) return 0;
    await initialize();
    return (await _plugin.pendingNotificationRequests())
        .where((item) => ownsSlot(item.id))
        .length;
  }

  static Future<void> _cancelSlots() async {
    await _plugin.cancel(id: legacyId);
    for (var i = 0; i < VerseNotificationSchedule.maxSlots; i++) {
      await _plugin.cancel(id: firstSlotId + i);
    }
  }

  static Future<void> cancelDailyReminder() => _serialize(() async {
    if (kIsWeb) return;
    await initialize();
    await _cancelSlots();
    await _plugin.cancel(id: previewId);
  });

  /// Test the actual scheduler with the app in the background, without opting
  /// into recurring notifications or altering saved hours.
  static Future<void> schedulePreview() => _serialize(() async {
    if (!await requestPermissions())
      throw StateError('Permiso de notificaciones denegado.');
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        (await _plugin.pendingNotificationRequests())
                .where((p) => p.id != previewId)
                .length >=
            64) {
      throw StateError(
        'No hay espacio para la prueba. Reduce otros recordatorios.',
      );
    }
    await _plugin.zonedSchedule(
      id: previewId,
      title: 'STK Haven · Prueba de versículos',
      body: 'La prueba programada llegó. Tus horarios se guardan por separado.',
      scheduledDate: tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(seconds: 30)),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  });

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.show(
      id: previewId,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
