import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ClockWorkout extends ActiveWorkoutNotifier {
  static late WorkoutSession initial;

  @override
  ActiveWorkoutState build() => ActiveWorkoutState(
        session: initial,
        globalTimerSeconds: 0, // Reproduces a stale restored fallback.
      );

  void editWithoutRestart(WorkoutSession edited) {
    state = state.copyWith(session: edited);
  }
}

void main() {
  test('elapsed provider emits a real first value despite stale zero fallback',
      () async {
    final started = DateTime.now().subtract(const Duration(minutes: 2));
    _ClockWorkout.initial = WorkoutSession(
      id: 'restored-session',
      routineNameSnapshot: 'Anterior',
      startedAt: started,
      finishedAt: null,
      durationSeconds: 0,
      exercises: const [],
    );

    final container = ProviderContainer(
      overrides: [
        activeWorkoutProvider.overrideWith(_ClockWorkout.new),
      ],
    );
    addTearDown(container.dispose);

    final seen = <int>[];
    final subscription = container.listen<AsyncValue<int>>(
      workoutTimerProvider,
      (_, next) {
        final value = next.asData?.value;
        if (value != null) seen.add(value);
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final first = await container.read(workoutTimerProvider.future);
    expect(first, greaterThanOrEqualTo(120));
    expect(first, lessThan(140));
    expect(seen, isNot(contains(0)));

    // Editing set-related session data preserves the ID and startedAt.
    // The duration stream must not flash a stale zero in this transition.
    container.read(activeWorkoutProvider.notifier);
    (container.read(activeWorkoutProvider.notifier) as _ClockWorkout)
        .editWithoutRestart(WorkoutSession(
      id: 'restored-session',
      routineNameSnapshot: 'Editada',
      startedAt: started,
      finishedAt: null,
      durationSeconds: 0,
      exercises: const [],
    ));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(workoutTimerProvider).value, greaterThanOrEqualTo(120));
    expect(seen, isNot(contains(0)));
  });
}
