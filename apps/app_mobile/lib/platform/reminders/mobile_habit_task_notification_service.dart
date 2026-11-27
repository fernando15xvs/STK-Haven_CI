import 'package:core/features/habits/application/habit_task_notification_service.dart';
import 'package:core/features/habits/application/focus_timer_notification_service.dart';
import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/habit_schedule_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gym_tracker/platform/reminders/mobile_local_notification_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

class MobileHabitTaskNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static Future<void>? _initialization;

  static Future<void> initialize() {
    if (kIsWeb) return Future<void>.value();
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    await MobileLocalNotificationTimezone.ensureInitialized();
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

    await cancel(task.id);
    final dueDates = HabitScheduleService.dueDates(
      task: task,
      from: from ?? DateTime.now(),
      days: 45,
    );
    if (dueDates.isEmpty) return false;

    final preferred = task.scheduledAt?.toLocal();
    final hour = preferred?.hour ?? 9;
    final minute = preferred?.minute ?? 0;
    final dates=<int,tz.TZDateTime>{};
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
        final slot=task.recurrence==HabitRecurrenceType.weekly&&task.weeklyGoal==null?candidate.weekday:0;
        dates.putIfAbsent(slot,()=>candidate);
        if(slot==0)break;
      }
    }
    if (dates.isEmpty) return false;

    for(final entry in dates.entries){
    await _plugin.zonedSchedule(
      id: entry.key==0?_notificationId(task.id):_notificationId('${task.id}:weekday:${entry.key}'),
      title: task.faithSpecific
          ? 'Momento de lectura · STK Haven'
          : 'Recordatorio · STK Haven',
      body: task.visibility==HabitTaskVisibility.private?'Recordatorio de una actividad personal.':task.title,
      scheduledDate: entry.value,
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
              : task.recurrence==HabitRecurrenceType.weekly
                ? task.weeklyGoal!=null?DateTimeComponents.time:DateTimeComponents.dayOfWeekAndTime
                : null,
    );
    }
    return true;
  }

  static Future<void> cancel(String taskId) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(id: _notificationId(taskId));
    for(var day=1;day<=7;day++){
      await _plugin.cancel(id:_notificationId('$taskId:weekday:$day'));
    }
  }

  static const _focusNotificationId=41921;
  static Future<void> scheduleFocus(DateTime deadline)async{
    if(kIsWeb)return;
    await initialize();
    final date=tz.TZDateTime.from(deadline,tz.local);
    if(!date.isAfter(tz.TZDateTime.now(tz.local)))return;
    await _plugin.zonedSchedule(id:_focusNotificationId,title:'STK Haven',body:'Tu sesión de enfoque ha terminado.',scheduledDate:date,
      notificationDetails:const NotificationDetails(android:AndroidNotificationDetails('focus_timer','Sesiones de enfoque',importance:Importance.defaultImportance),
        iOS:DarwinNotificationDetails(presentAlert:true,presentSound:false)),androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle);
  }
  static Future<void> cancelFocus()async{
    if(kIsWeb)return;await initialize();await _plugin.cancel(id:_focusNotificationId);
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

class MobileHabitTaskNotificationBackend implements HabitTaskNotificationBackend {
  const MobileHabitTaskNotificationBackend();

  @override
  Future<void> initialize() => MobileHabitTaskNotificationService.initialize();

  @override
  Future<bool> requestPermission() =>
      MobileHabitTaskNotificationService.requestPermission();

  @override
  Future<bool> scheduleNext(
    HabitTask task, {
    DateTime? from,
    bool requestPermissionIfNeeded = true,
  }) => MobileHabitTaskNotificationService.scheduleNext(
    task,
    from: from,
    requestPermissionIfNeeded: requestPermissionIfNeeded,
  );

  @override
  Future<void> cancel(String taskId) =>
      MobileHabitTaskNotificationService.cancel(taskId);
}

class MobileFocusTimerNotificationBackend implements FocusTimerNotificationBackend {
  const MobileFocusTimerNotificationBackend();
  @override Future<bool> requestPermission()=>MobileHabitTaskNotificationService.requestPermission();
  @override Future<void> schedule(DateTime deadline)=>MobileHabitTaskNotificationService.scheduleFocus(deadline);
  @override Future<void> cancel()=>MobileHabitTaskNotificationService.cancelFocus();
}
