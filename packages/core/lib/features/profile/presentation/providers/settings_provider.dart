import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/profile/data/settings_repository.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/core/services/daily_verse_settings_service.dart';
import 'package:core/core/services/workout_reminder_settings_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final box = Hive.box(HiveBoxes.metadata);
  return SettingsRepository(box);
});

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<SettingsState> {
  late final SettingsRepository _repository;

  @override
  SettingsState build() {
    _repository = ref.watch(settingsRepositoryProvider);
    return _repository.getSettings();
  }

  void updateSettings(SettingsState newSettings) {
    state = newSettings;
    _repository.saveSettings(state);
  }

  Future<void> updateTimerSound(bool isEnabled) async {
    final newState = state.copyWith(timerSoundEnabled: isEnabled);
    state = newState;
    await _repository.saveSettings(newState);
  }

  Future<void> setVibrationEnabled(bool isEnabled) async {
    final newState = state.copyWith(vibrationEnabled: isEnabled);
    state = newState;
    await _repository.saveSettings(newState);
  }

  Future<void> completeOnboarding() async {
    final newState = state.copyWith(hasCompletedOnboarding: true);
    state = newState;
    await _repository.saveSettings(newState);
  }

  void setRirEnabled(bool enabled) {
    updateSettings(state.copyWith(isRirEnabled: enabled));
  }

  void setAutoRestEnabled(bool enabled) {
    updateSettings(state.copyWith(autoRestEnabled: enabled));
  }

  void setWeightUnit(WeightUnit unit) {
    updateSettings(state.copyWith(weightUnit: unit));
  }

  void setDefaultIncrement(double incrementInActiveUnit, WeightUnit activeUnit) {
    final incrementKg =
        WeightConverter.toCanonicalKg(incrementInActiveUnit, activeUnit);
    updateSettings(state.copyWith(defaultIncrement: incrementKg));
  }

  void setUnilateralSideRestSeconds(int seconds) {
    final safeSeconds = seconds.clamp(0, 600).toInt();
    updateSettings(state.copyWith(unilateralSideRestSeconds: safeSeconds));
  }

  void setUnilateralSameWeightByDefault(bool enabled) {
    updateSettings(state.copyWith(unilateralSameWeightByDefault: enabled));
  }

  void setPreferredUnilateralStartSide(PreferredWorkoutSide side) {
    updateSettings(state.copyWith(preferredUnilateralStartSide: side));
  }

  void setPrefillExerciseMemoryByDefault(bool enabled) {
    updateSettings(state.copyWith(prefillExerciseMemoryByDefault: enabled));
  }

  void setPerformanceMode(PerformanceMode mode) {
    updateSettings(state.copyWith(performanceMode: mode));
  }

  void setShowDailyVerse(bool show) {
    updateSettings(state.copyWith(showDailyVerse: show));
  }

  Future<void> setDailyVerseNotifications(bool enable) async {
    final effectiveValue = await configureDailyVerseNotifications(enable);
    final newState = state.copyWith(
      dailyVerseNotifications: effectiveValue,
    );
    state = newState;
    await _repository.saveSettings(newState);
  }

  void setCloudSyncEnabled(bool enabled) {
    updateSettings(state.copyWith(cloudSyncEnabled: enabled));
  }

  void setReduceMotion(bool enabled) {
    updateSettings(state.copyWith(reduceMotion: enabled));
  }

  Future<void> setWorkoutReminders(bool enabled) async {
    final effectiveValue = await configureWorkoutReminder(
      enabled: enabled,
      hour: state.workoutReminderHour,
      minute: state.workoutReminderMinute,
    );
    final newState = state.copyWith(workoutRemindersEnabled: effectiveValue);
    state = newState;
    await _repository.saveSettings(newState);
  }

  Future<void> setWorkoutReminderTime({
    required int hour,
    required int minute,
  }) async {
    final safeHour = hour.clamp(0, 23).toInt();
    final safeMinute = minute.clamp(0, 59).toInt();
    var enabled = state.workoutRemindersEnabled;
    if (enabled) {
      enabled = await configureWorkoutReminder(
        enabled: true,
        hour: safeHour,
        minute: safeMinute,
      );
    }
    final newState = state.copyWith(
      workoutRemindersEnabled: enabled,
      workoutReminderHour: safeHour,
      workoutReminderMinute: safeMinute,
    );
    state = newState;
    await _repository.saveSettings(newState);
  }
}
