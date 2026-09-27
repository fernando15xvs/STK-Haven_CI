import 'package:core/domain/models/daily_steps_state.dart';
import 'package:core/domain/models/hydration_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

class WellnessRepository {
  static const String hydrationPreferencesKey = 'hydration_preferences_v1';
  static const String _stepsPrefix = 'daily_steps_v1_';

  final Box _metadata;

  WellnessRepository(this._metadata);

  HydrationPreferences getHydrationPreferences() {
    final raw = _metadata.get(hydrationPreferencesKey);
    if (raw is! Map) return const HydrationPreferences();
    try {
      return HydrationPreferences.fromJson(
        Map<String, dynamic>.from(raw),
      );
    } catch (_) {
      return const HydrationPreferences();
    }
  }

  Future<void> saveHydrationPreferences(
    HydrationPreferences preferences,
  ) async {
    await _metadata.put(hydrationPreferencesKey, preferences.toJson());
  }

  DailyStepsState getStepsForDate(String dateString) {
    final raw = _metadata.get('$_stepsPrefix$dateString');
    if (raw is! Map) {
      return DailyStepsState(dateString: dateString);
    }
    try {
      final restored = DailyStepsState.fromJson(
        Map<String, dynamic>.from(raw),
      );
      return restored.dateString == dateString
          ? restored
          : DailyStepsState(dateString: dateString);
    } catch (_) {
      return DailyStepsState(dateString: dateString);
    }
  }

  Future<void> saveSteps(DailyStepsState state) async {
    await _metadata.put('$_stepsPrefix${state.dateString}', state.toJson());
  }
}
