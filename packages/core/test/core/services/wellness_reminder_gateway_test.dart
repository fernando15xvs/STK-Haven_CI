import 'package:core/core/services/hydration_reminder_service.dart';
import 'package:core/core/services/step_goal_reminder_service.dart';
import 'package:core/domain/models/step_goal_preferences.dart';
import 'package:test/test.dart';

class _WaterSpy implements HydrationReminderBackend {
  final calls = <String>[];
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
  Future<bool> syncNextReminder({
    required bool enabled, required int currentMl,
    required int targetMl, required int reminderHour,
    bool requestPermissionIfNeeded = false,
  }) async {
    calls.add('sync:$enabled:$currentMl:$targetMl:$reminderHour:$requestPermissionIfNeeded');
    return true;
  }
}

class _StepsSpy implements StepGoalReminderBackend {
  final calls = <String>[];
  StepGoalPreferences? receivedPreferences;
  DateTime? receivedSyncDate;
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
  Future<bool> syncToday({
    required StepGoalPreferences preferences,
    required int currentSteps, required DateTime? lastSyncedAt,
    bool requestPermissionIfNeeded = false,
  }) async {
    receivedPreferences = preferences;
    receivedSyncDate = lastSyncedAt;
    calls.add('sync:$currentSteps:$requestPermissionIfNeeded');
    return true;
  }
}

void main() {
  setUp(() {
    HydrationReminderService.installBackend(null);
    StepGoalReminderService.installBackend(null);
  });
  tearDown(() {
    HydrationReminderService.installBackend(null);
    StepGoalReminderService.installBackend(null);
  });

  test('without Mobile, no native permission or scheduling is claimed', () async {
    expect(await HydrationReminderService.requestPermission(), false);
    expect(await StepGoalReminderService.requestPermission(), false);
    expect(await HydrationReminderService.syncNextReminder(
      enabled: true, currentMl: 250, targetMl: 2000, reminderHour: 20,
    ), false);
    expect(await StepGoalReminderService.syncToday(
      preferences: const StepGoalPreferences(reminderEnabled: true),
      currentSteps: 4000, lastSyncedAt: null,
    ), false);
    await HydrationReminderService.initialize();
    await StepGoalReminderService.initialize();
    await HydrationReminderService.cancel();
    await StepGoalReminderService.cancel();
  });

  test('hydration port retains values, permission intent and cancellation', () async {
    final spy = _WaterSpy();
    HydrationReminderService.installBackend(spy);
    await HydrationReminderService.initialize();
    expect(await HydrationReminderService.requestPermission(), true);
    expect(await HydrationReminderService.syncNextReminder(
      enabled: true, currentMl: 725, targetMl: 2300,
      reminderHour: 22, requestPermissionIfNeeded: true,
    ), true);
    await HydrationReminderService.cancel();
    expect(spy.calls, [
      'initialize', 'permission', 'sync:true:725:2300:22:true', 'cancel',
    ]);
  });

  test('steps port retains preferences, date and permission intent', () async {
    final spy = _StepsSpy();
    StepGoalReminderService.installBackend(spy);
    const prefs = StepGoalPreferences(
      targetSteps: 12000, reminderEnabled: true,
      reminderCadence: StepReminderCadence.gentle,
    );
    final synced = DateTime(2026, 11, 23, 10, 5);
    await StepGoalReminderService.initialize();
    expect(await StepGoalReminderService.requestPermission(), true);
    expect(await StepGoalReminderService.syncToday(
      preferences: prefs, currentSteps: 5000, lastSyncedAt: synced,
      requestPermissionIfNeeded: true,
    ), true);
    await StepGoalReminderService.cancel();
    expect(identical(spy.receivedPreferences, prefs), true);
    expect(spy.receivedSyncDate, same(synced));
    expect(spy.calls, [
      'initialize', 'permission', 'sync:5000:true', 'cancel',
    ]);
  });
}
