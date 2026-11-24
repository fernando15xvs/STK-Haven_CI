import 'package:core/core/services/workout_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend implements WorkoutNotificationBackend {
  final events = <String>[];

  @override
  Future<void> initialize() async => events.add('init');

  @override
  Future<bool> requestNotificationPermission() async {
    events.add('permission');
    return true;
  }

  @override
  Future<void> scheduleRestTimerNotification(
    DateTime endTime, {String? workoutSessionId}
  ) async => events.add('rest:${endTime.toIso8601String()}:$workoutSessionId');

  @override
  Future<void> cancelRestTimerNotification() async => events.add('cancel-rest');

  @override
  Future<bool> scheduleDailyWorkoutReminder({
    required int hour, required int minute, bool requestPermission = true,
  }) async {
    events.add('daily:$hour:$minute:$requestPermission');
    return true;
  }

  @override
  Future<void> scheduleUnfinishedWorkoutReminder({
    required DateTime lastActivityAt, required String workoutName,
  }) async => events.add('unfinished:$workoutName:${lastActivityAt.year}');

  @override
  Future<void> cancelUnfinishedWorkoutReminders() async =>
      events.add('cancel-unfinished');

  @override
  Future<void> cancelDailyWorkoutReminder() async =>
      events.add('cancel-daily');
}

class _SilentBackend implements WorkoutNotificationBackend {
  const _SilentBackend();

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestNotificationPermission() async => false;
  @override
  Future<void> scheduleRestTimerNotification(
    DateTime endTime, {String? workoutSessionId}
  ) async {}
  @override
  Future<void> cancelRestTimerNotification() async {}
  @override
  Future<bool> scheduleDailyWorkoutReminder({
    required int hour, required int minute, bool requestPermission = true,
  }) async => false;
  @override
  Future<void> scheduleUnfinishedWorkoutReminder({
    required DateTime lastActivityAt, required String workoutName,
  }) async {}
  @override
  Future<void> cancelUnfinishedWorkoutReminders() async {}
  @override
  Future<void> cancelDailyWorkoutReminder() async {}
}

void main() {
  tearDown(() {
    WorkoutNotificationService.installBackend(const _SilentBackend());
  });

  test('Core notification gateway works without native plugins', () async {
    final gateway = const _SilentBackend();
    WorkoutNotificationService.installBackend(gateway);
    expect(await WorkoutNotificationService.requestNotificationPermission(), false);
    expect(await WorkoutNotificationService.scheduleDailyWorkoutReminder(
      hour: 8, minute: 15,
    ), false);
    await WorkoutNotificationService.cancelRestTimerNotification();
  });

  test('Core facade preserves scheduling arguments and the shared backend', () async {
    final backend = _FakeBackend();
    WorkoutNotificationService.installBackend(backend);
    final end = DateTime.utc(2026, 11, 23, 20);
    await WorkoutNotificationService.initialize();
    expect(await WorkoutNotificationService.requestNotificationPermission(), true);
    await WorkoutNotificationService.scheduleRestTimerNotification(
      end, workoutSessionId: 'same-workout-id',
    );
    await WorkoutNotificationService.cancelRestTimerNotification();
    expect(await WorkoutNotificationService.scheduleDailyWorkoutReminder(
      hour: 7, minute: 30, requestPermission: false,
    ), true);
    await WorkoutNotificationService.scheduleUnfinishedWorkoutReminder(
      lastActivityAt: end, workoutName: 'Mi rutina',
    );
    await WorkoutNotificationService.cancelUnfinishedWorkoutReminders();
    await WorkoutNotificationService.cancelDailyWorkoutReminder();

    expect(backend.events, [
      'init',
      'permission',
      'rest:2026-11-23T20:00:00.000Z:same-workout-id',
      'cancel-rest',
      'daily:7:30:false',
      'unfinished:Mi rutina:2026',
      'cancel-unfinished',
      'cancel-daily',
    ]);
  });
}
