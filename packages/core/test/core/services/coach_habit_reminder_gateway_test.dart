import 'package:core/core/services/coach_pro_local_reminder_service.dart';
import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/coach/application/coach_task_notification_service.dart';
import 'package:core/features/coach_pro/domain/coach_pro_reminder_consent.dart';
import 'package:core/features/habits/application/habit_task_notification_service.dart';
import 'package:test/test.dart';

class _CoachTaskSpy implements CoachTaskNotificationBackend {
  final calls = <String>[];
  HabitTask? task;
  DateTime? from;
  bool? requestPermissionIfNeeded;

  @override
  Future<void> initialize() async { calls.add('initialize'); }

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return true;
  }

  @override
  Future<bool> scheduleNextReminder(
    HabitTask task, {
    DateTime? from,
    bool requestPermissionIfNeeded = true,
  }) async {
    this.task = task;
    this.from = from;
    this.requestPermissionIfNeeded = requestPermissionIfNeeded;
    calls.add('schedule');
    return true;
  }

  @override
  Future<void> cancelReminder(String taskId) async {
    calls.add('cancel:$taskId');
  }
}

class _HabitTaskSpy implements HabitTaskNotificationBackend {
  final calls = <String>[];
  HabitTask? task;
  DateTime? from;
  bool? requestPermissionIfNeeded;

  @override
  Future<void> initialize() async { calls.add('initialize'); }

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return true;
  }

  @override
  Future<bool> scheduleNext(
    HabitTask task, {
    DateTime? from,
    bool requestPermissionIfNeeded = true,
  }) async {
    this.task = task;
    this.from = from;
    this.requestPermissionIfNeeded = requestPermissionIfNeeded;
    calls.add('schedule');
    return true;
  }

  @override
  Future<void> cancel(String taskId) async {
    calls.add('cancel:$taskId');
  }
}

class _CoachProSpy implements CoachProLocalReminderBackend {
  final calls = <String>[];
  CoachProReminderConsent? lastConsent;

  @override
  Future<void> initialize() async { calls.add('initialize'); }

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return true;
  }

  @override
  Future<void> cancel() async { calls.add('cancel'); }

  @override
  Future<void> synchronize(CoachProReminderConsent consent) async {
    lastConsent = consent;
    calls.add('synchronize');
  }
}

void main() {
  setUp(() {
    CoachTaskNotificationService.installBackend(null);
    HabitTaskNotificationService.installBackend(null);
    CoachProLocalReminderService.installBackend(null);
  });
  tearDown(() {
    CoachTaskNotificationService.installBackend(null);
    HabitTaskNotificationService.installBackend(null);
    CoachProLocalReminderService.installBackend(null);
  });

  final createdAt = DateTime(2026, 11, 23, 8);
  final task = HabitTask(
    id: 'coach::abc',
    title: 'Rutina asignada',
    createdAt: createdAt,
    updatedAt: createdAt,
    reminderEnabled: true,
  );
  final consent = CoachProReminderConsent.fromJson({
    'enabled': true,
    'hour_local': 19,
    'weekdays': [1, 4],
    'cadence_revision': 3,
  });

  test('Core has no native reminder behavior without installed backends', () async {
    expect(await CoachTaskNotificationService.requestPermission(), false);
    expect(await HabitTaskNotificationService.requestPermission(), false);
    expect(await CoachProLocalReminderService.requestPermission(), false);
    expect(await CoachTaskNotificationService.scheduleNextReminder(task), false);
    expect(await HabitTaskNotificationService.scheduleNext(task), false);
    await CoachTaskNotificationService.initialize();
    await HabitTaskNotificationService.initialize();
    await CoachProLocalReminderService.initialize();
    await CoachTaskNotificationService.cancelReminder(task.id);
    await HabitTaskNotificationService.cancel(task.id);
    await CoachProLocalReminderService.synchronize(consent);
    await CoachProLocalReminderService.cancel();
    expect(CoachProLocalReminderService.notificationIds, [41810, 41811, 41812]);
  });

  test('coach task port forwards exact task, date, permission and cancellation', () async {
    final spy = _CoachTaskSpy();
    CoachTaskNotificationService.installBackend(spy);
    final from = DateTime.utc(2026, 11, 24, 12);
    await CoachTaskNotificationService.initialize();
    expect(await CoachTaskNotificationService.requestPermission(), true);
    expect(await CoachTaskNotificationService.scheduleNextReminder(
      task, from: from, requestPermissionIfNeeded: false,
    ), true);
    await CoachTaskNotificationService.cancelReminder(task.id);
    expect(identical(spy.task, task), true);
    expect(identical(spy.from, from), true);
    expect(spy.requestPermissionIfNeeded, false);
    expect(spy.calls, ['initialize', 'permission', 'schedule', 'cancel:coach::abc']);
  });

  test('habit task port preserves original scheduling options', () async {
    final spy = _HabitTaskSpy();
    HabitTaskNotificationService.installBackend(spy);
    final from = DateTime(2026, 11, 25);
    await HabitTaskNotificationService.initialize();
    expect(await HabitTaskNotificationService.requestPermission(), true);
    expect(await HabitTaskNotificationService.scheduleNext(
      task, from: from,
    ), true);
    await HabitTaskNotificationService.cancel(task.id);
    expect(identical(spy.task, task), true);
    expect(identical(spy.from, from), true);
    expect(spy.requestPermissionIfNeeded, true);
    expect(spy.calls, ['initialize', 'permission', 'schedule', 'cancel:coach::abc']);
  });

  test('Coach Pro port forwards consent object without changing privacy metadata', () async {
    final spy = _CoachProSpy();
    CoachProLocalReminderService.installBackend(spy);
    await CoachProLocalReminderService.initialize();
    expect(await CoachProLocalReminderService.requestPermission(), true);
    await CoachProLocalReminderService.synchronize(consent);
    await CoachProLocalReminderService.cancel();
    expect(identical(spy.lastConsent, consent), true);
    expect(spy.lastConsent!.weekdays, {1, 4});
    expect(spy.calls, ['initialize', 'permission', 'synchronize', 'cancel']);
    expect(CoachProLocalReminderService.notificationIds, [41810, 41811, 41812]);
  });
}
