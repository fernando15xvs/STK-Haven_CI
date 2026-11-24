import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/daily_steps_state.dart';
import 'package:core/domain/models/hydration_preferences.dart';
import 'package:core/domain/models/step_goal_preferences.dart';
import 'package:core/domain/models/wellness_goal_change.dart';
import 'package:core/features/home/data/wellness_repository.dart';
import 'package:riverpod/riverpod.dart';
import 'package:hive/hive.dart';

final wellnessRepositoryProvider = Provider<WellnessRepository>((ref) {
  return WellnessRepository(Hive.box(HiveBoxes.metadata));
});

class HydrationPreferencesNotifier extends Notifier<HydrationPreferences> {
  WellnessRepository get _repository => ref.read(wellnessRepositoryProvider);

  @override
  HydrationPreferences build() => _repository.getHydrationPreferences();

  Future<void> setTargetMl(int value, {
    WellnessGoalChangeSource source=WellnessGoalChangeSource.preferences,
  }) async {
    final target=value.clamp(1000,5000).toInt();
    if(target==state.targetMl)return;
    // The target and its audit share one preference JSON write. Failed
    // persistence cannot leave a false on-screen change or a phantom event.
    final updated=state.copyWith(
      targetMl:target,
      goalChanges:WellnessGoalChange.append(state.goalChanges,
        WellnessGoalChange(
          previousTarget:state.targetMl,newTarget:target,
          changedAt:DateTime.now().toUtc(),source:source)),
    );
    await _repository.saveHydrationPreferences(updated);
    state=updated;
  }

  Future<void> setReminderEnabled(bool enabled) async {
    if(state.reminderEnabled==enabled)return;
    final updated=state.copyWith(reminderEnabled:enabled);
    await _repository.saveHydrationPreferences(updated);
    state=updated;
  }

  Future<void> setReminderHour(int hour) async {
    final chosen=hour.clamp(6,22).toInt();
    if(state.reminderHour==chosen)return;
    final updated=state.copyWith(reminderHour:chosen);
    await _repository.saveHydrationPreferences(updated);
    state=updated;
  }

  Future<void> markReminderSent(DateTime instant) async {
    final date =
        '${instant.year}-${instant.month.toString().padLeft(2, '0')}-${instant.day.toString().padLeft(2, '0')}';
    if(state.lastReminderDate==date)return;
    final updated=state.copyWith(lastReminderDate:date);
    await _repository.saveHydrationPreferences(updated);
    state=updated;
  }
}

final hydrationPreferencesProvider =
    NotifierProvider<HydrationPreferencesNotifier, HydrationPreferences>(
  HydrationPreferencesNotifier.new,
);

class StepGoalPreferencesNotifier extends Notifier<StepGoalPreferences> {
  WellnessRepository get _repository => ref.read(wellnessRepositoryProvider);

  @override
  StepGoalPreferences build() => _repository.getStepGoalPreferences();

  Future<void> setTargetSteps(int value, {
    WellnessGoalChangeSource source=WellnessGoalChangeSource.preferences,
  }) async {
    final target=value.clamp(1000,50000).toInt();
    if(target==state.targetSteps)return;
    final updated=state.copyWith(
      targetSteps:target,
      goalChanges:WellnessGoalChange.append(state.goalChanges,
        WellnessGoalChange(
          previousTarget:state.targetSteps,newTarget:target,
          changedAt:DateTime.now().toUtc(),source:source)),
    );
    await _repository.saveStepGoalPreferences(updated);
    state=updated;
  }

  Future<void> setReminderEnabled(bool enabled) async {
    if(state.reminderEnabled==enabled)return;
    final updated=state.copyWith(reminderEnabled:enabled);
    await _repository.saveStepGoalPreferences(updated);
    state=updated;
  }

  Future<void> setReminderCadence(StepReminderCadence cadence) async {
    if(state.reminderCadence==cadence)return;
    final updated=state.copyWith(reminderCadence:cadence);
    await _repository.saveStepGoalPreferences(updated);
    state=updated;
  }
}

final stepGoalPreferencesProvider =
    NotifierProvider<StepGoalPreferencesNotifier, StepGoalPreferences>(
  StepGoalPreferencesNotifier.new,
);

class DailyStepsNotifier extends Notifier<DailyStepsState> {
  WellnessRepository get _repository => ref.read(wellnessRepositoryProvider);

  @override
  DailyStepsState build() => _repository.getStepsForDate(_today());

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void checkDateAndRefresh() {
    final today = _today();
    if (state.dateString != today) {
      state = _repository.getStepsForDate(today);
    }
  }

  Future<void> setSteps(
    int value, {
    bool deviceSynced = false,
  }) async {
    checkDateAndRefresh();
    final updated=state.copyWith(
      steps: value.clamp(0, 250000).toInt(),
      deviceSynced: deviceSynced,
      lastSyncedAt: deviceSynced ? DateTime.now() : state.lastSyncedAt,
    );
    // Never display sensor readings not yet committed to the dated record.
    await _repository.saveSteps(updated);
    state=updated;
  }

  Future<void> addSteps(int delta) =>
      setSteps(state.steps + delta, deviceSynced: false);
}

final dailyStepsProvider =
    NotifierProvider<DailyStepsNotifier, DailyStepsState>(
  DailyStepsNotifier.new,
);
