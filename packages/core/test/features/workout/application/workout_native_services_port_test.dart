import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/workout_native_services_port.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

class _RecordingNativeServices implements WorkoutNativeServices {
  final events = <String>[];

  @override
  Future<void> scheduleRestTimerNotification(
    DateTime endsAt, {String? workoutSessionId}
  ) async {
    events.add('rest:${workoutSessionId ?? 'none'}:${endsAt.toUtc().toIso8601String()}');
  }

  @override
  Future<void> cancelRestTimerNotification() async {
    events.add('cancelRest');
  }

  @override
  Future<void> scheduleUnfinishedWorkoutReminder({
    required DateTime lastActivityAt,
    required String workoutName,
  }) async {
    events.add('unfinished:$workoutName');
  }

  @override
  Future<void> cancelUnfinishedWorkoutReminders() async {
    events.add('cancelUnfinished');
  }

  @override
  void playRestCompletionCueIfForeground({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) {
    events.add('cue:$soundEnabled:$vibrationEnabled');
  }
}

void main() {
  test('pure Dart port has a safe default without a native platform', () async {
    final native = const NoOpWorkoutNativeServices();
    final deadline = DateTime.utc(2026, 11, 23, 20);
    await native.scheduleRestTimerNotification(
      deadline,
      workoutSessionId: 'session-persisted',
    );
    await native.cancelRestTimerNotification();
    await native.scheduleUnfinishedWorkoutReminder(
      lastActivityAt: deadline,
      workoutName: 'Rutina existente',
    );
    await native.cancelUnfinishedWorkoutReminders();
    native.playRestCompletionCueIfForeground(
      soundEnabled: true,
      vibrationEnabled: true,
    );
  });

  test('Riverpod port override transports session identity and preferences', () async {
    final fake = _RecordingNativeServices();
    final container = ProviderContainer(
      overrides: [workoutNativeServicesProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final port = container.read(workoutNativeServicesProvider);
    expect(identical(port, fake), isTrue);

    final end = DateTime.utc(2026, 11, 23, 20);
    await port.scheduleRestTimerNotification(end, workoutSessionId: 'same-id');
    port.playRestCompletionCueIfForeground(
      soundEnabled: false,
      vibrationEnabled: true,
    );
    await port.cancelRestTimerNotification();
    await port.scheduleUnfinishedWorkoutReminder(
      lastActivityAt: end,
      workoutName: 'Lower A',
    );
    await port.cancelUnfinishedWorkoutReminders();

    expect(fake.events, [
      'rest:same-id:2026-11-23T20:00:00.000Z',
      'cue:false:true',
      'cancelRest',
      'unfinished:Lower A',
      'cancelUnfinished',
    ]);
  });
}
