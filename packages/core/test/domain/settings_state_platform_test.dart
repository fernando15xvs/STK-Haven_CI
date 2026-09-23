import 'package:flutter_test/flutter_test.dart';
import 'package:core/domain/models/settings_state.dart';

void main() {
  group('SettingsState platform preferences', () {
    test('uses safe local-first defaults', () {
      const state = SettingsState();

      expect(state.cloudSyncEnabled, isFalse);
      expect(state.reduceMotion, isFalse);
      expect(state.workoutRemindersEnabled, isFalse);
      expect(state.workoutReminderHour, 18);
      expect(state.workoutReminderMinute, 0);
      expect(state.unilateralSideRestSeconds, 60);
    });

    test('round-trips platform preferences through JSON', () {
      final state = const SettingsState().copyWith(
        cloudSyncEnabled: true,
        reduceMotion: true,
        workoutRemindersEnabled: true,
        workoutReminderHour: 7,
        workoutReminderMinute: 35,
        unilateralSideRestSeconds: 45,
      );

      final restored = SettingsState.fromJson(state.toJson());

      expect(restored.cloudSyncEnabled, isTrue);
      expect(restored.reduceMotion, isTrue);
      expect(restored.workoutRemindersEnabled, isTrue);
      expect(restored.workoutReminderHour, 7);
      expect(restored.workoutReminderMinute, 35);
      expect(restored.unilateralSideRestSeconds, 45);
    });

    test('keeps backwards compatibility with backups missing new keys', () {
      final restored = SettingsState.fromJson(<String, dynamic>{
        'weightUnit': 'kg',
      });

      expect(restored.cloudSyncEnabled, isFalse);
      expect(restored.reduceMotion, isFalse);
      expect(restored.workoutRemindersEnabled, isFalse);
      expect(restored.workoutReminderHour, 18);
      expect(restored.workoutReminderMinute, 0);
      expect(restored.unilateralSideRestSeconds, 60);
    });

    test('clamps corrupted reminder times and side rest', () {
      final restored = SettingsState.fromJson(<String, dynamic>{
        'workoutReminderHour': 99,
        'workoutReminderMinute': -10,
        'unilateralSideRestSeconds': 9999,
      });

      expect(restored.workoutReminderHour, 23);
      expect(restored.workoutReminderMinute, 0);
      expect(restored.unilateralSideRestSeconds, 600);
    });
  });
}
