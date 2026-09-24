import 'package:core/domain/models/habit_study_timer.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final habitStudyTimerProvider =
    NotifierProvider<HabitStudyTimerNotifier, HabitStudyTimerState?>(
  HabitStudyTimerNotifier.new,
);

class HabitStudyTimerNotifier extends Notifier<HabitStudyTimerState?> {
  @override
  HabitStudyTimerState? build() {
    final repository = ref.watch(habitTaskRepositoryProvider);
    return repository.getActiveStudyTimer();
  }

  Future<void> start({
    required String taskId,
    required int targetMinutes,
  }) async {
    final now = DateTime.now();
    final next = HabitStudyTimerState(
      taskId: taskId,
      targetSeconds: targetMinutes.clamp(0, 1440).toInt() * 60,
      runningSince: now,
      updatedAt: now,
    );
    await ref.read(habitTaskRepositoryProvider).saveActiveStudyTimer(next);
    state = next;
  }

  Future<void> pause() async {
    final current = state;
    if (current == null || !current.isRunning) return;
    final next = current.pause(DateTime.now());
    await ref.read(habitTaskRepositoryProvider).saveActiveStudyTimer(next);
    state = next;
  }

  Future<void> resume() async {
    final current = state;
    if (current == null || current.isRunning) return;
    final next = current.resume(DateTime.now());
    await ref.read(habitTaskRepositoryProvider).saveActiveStudyTimer(next);
    state = next;
  }

  Future<void> clear() async {
    await ref.read(habitTaskRepositoryProvider).clearActiveStudyTimer();
    state = null;
  }
}
