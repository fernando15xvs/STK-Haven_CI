import 'package:core/domain/models/daily_steps_state.dart';
import 'package:core/domain/models/hydration_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hydration preferences restore safe configurable values', () {
    final restored = HydrationPreferences.fromJson({
      'targetMl': 4250,
      'reminderEnabled': true,
      'reminderHour': 20,
    });

    expect(restored.targetMl, 4250);
    expect(restored.reminderEnabled, isTrue);
    expect(restored.reminderHour, 20);
  });

  test('hydration preferences clamp malformed legacy values', () {
    final restored = HydrationPreferences.fromJson({
      'targetMl': 99999,
      'reminderHour': 2,
    });

    expect(restored.targetMl, 5000);
    expect(restored.reminderHour, 6);
  });

  test('daily steps state survives json round-trip', () {
    final now = DateTime(2026, 9, 27, 9, 30);
    final original = DailyStepsState(
      dateString: '2026-09-27',
      steps: 4321,
      deviceSynced: true,
      lastSyncedAt: now,
    );

    final restored = DailyStepsState.fromJson(original.toJson());

    expect(restored.dateString, original.dateString);
    expect(restored.steps, 4321);
    expect(restored.deviceSynced, isTrue);
    expect(restored.lastSyncedAt, now);
  });
}
