import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/daily_steps_state.dart';
import 'package:core/domain/models/hydration_preferences.dart';
import 'package:core/domain/models/step_goal_preferences.dart';
import 'package:core/features/home/data/wellness_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final wellnessRepositoryProvider = Provider<WellnessRepository>((ref) {
  return WellnessRepository(Hive.box(HiveBoxes.metadata));
});

class HydrationPreferencesNotifier extends Notifier<HydrationPreferences> {
  WellnessRepository get _repository => ref.read(wellnessRepositoryProvider);

  @override
  HydrationPreferences build() => _repository.getHydrationPreferences();

  Future<void> setTargetMl(int value) async {
    state = state.copyWith(targetMl: value.clamp(1000, 5000).toInt());
    await _repository.saveHydrationPreferences(state);
  }

  Future<void> setReminderEnabled(bool enabled) async {
    state = state.copyWith(reminderEnabled: enabled);
    await _repository.saveHydrationPreferences(state);
  }

  Future<void> setReminderHour(int hour) async {
    state = state.copyWith(reminderHour: hour.clamp(6, 22).toInt());
    await _repository.saveHydrationPreferences(state);
  }

  Future<void> markReminderSent(DateTime instant) async {
    final date =
        '${instant.year}-${instant.month.toString().padLeft(2, '0')}-${instant.day.toString().padLeft(2, '0')}';
    state = state.copyWith(lastReminderDate: date);
    await _repository.saveHydrationPreferences(state);
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

  Future<void> setTargetSteps(int value) async {
    state = state.copyWith(
      targetSteps: value.clamp(1000, 50000).toInt(),
    );
    await _repository.saveStepGoalPreferences(state);
  }

  Future<void> setReminderEnabled(bool enabled) async {
    state = state.copyWith(reminderEnabled: enabled);
    await _repository.saveStepGoalPreferences(state);
  }

  Future<void> setReminderCadence(StepReminderCadence cadence) async {
    state = state.copyWith(reminderCadence: cadence);
    await _repository.saveStepGoalPreferences(state);
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
    state = state.copyWith(
      steps: value.clamp(0, 250000).toInt(),
      deviceSynced: deviceSynced,
      lastSyncedAt: deviceSynced ? DateTime.now() : state.lastSyncedAt,
    );
    await _repository.saveSteps(state);
  }

  Future<void> addSteps(int delta) =>
      setSteps(state.steps + delta, deviceSynced: false);
}

final dailyStepsProvider =
    NotifierProvider<DailyStepsNotifier, DailyStepsState>(
  DailyStepsNotifier.new,
);
