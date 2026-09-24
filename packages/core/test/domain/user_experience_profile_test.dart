import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserExperienceProfile', () {
    test('fresh profile keeps optional modules opt-in', () {
      const profile = UserExperienceProfile();

      expect(profile.capabilities, {UserCapability.athlete});
      expect(profile.faithPreference, FaithContentPreference.undecided);
      expect(profile.faithEnabled, isFalse);
      expect(profile.hasDecidedFaithPreference, isFalse);
      expect(profile.habitsEnabled, isFalse);
      expect(profile.onboardingVersion, 0);
    });

    test('round-trips onboarding preferences through JSON', () {
      final profile = UserExperienceProfile(
        capabilities: const {
          UserCapability.athlete,
          UserCapability.coach,
        },
        trainingGoal: TrainingGoal.hypertrophy,
        trainingExperience: TrainingExperience.intermediate,
        trainingDaysPerWeek: 4,
        sessionDuration: SessionDurationPreference.minutes60,
        trainingEnvironment: TrainingEnvironment.fullGym,
        planningPreference: PlanningPreference.recommendation,
        weightUnit: WeightUnit.lb,
        workoutRemindersWanted: true,
        faithPreference: FaithContentPreference.enabled,
        habitsEnabled: true,
        onboardingVersion: UserExperienceProfile.currentOnboardingVersion,
      );

      final restored = UserExperienceProfile.fromJson(profile.toJson());

      expect(restored.capabilities, profile.capabilities);
      expect(restored.trainingGoal, profile.trainingGoal);
      expect(restored.trainingExperience, profile.trainingExperience);
      expect(restored.trainingDaysPerWeek, 4);
      expect(restored.sessionDuration, profile.sessionDuration);
      expect(restored.trainingEnvironment, profile.trainingEnvironment);
      expect(restored.planningPreference, profile.planningPreference);
      expect(restored.weightUnit, WeightUnit.lb);
      expect(restored.workoutRemindersWanted, isTrue);
      expect(restored.faithPreference, FaithContentPreference.enabled);
      expect(restored.faithEnabled, isTrue);
      expect(restored.habitsEnabled, isTrue);
      expect(
        restored.onboardingVersion,
        UserExperienceProfile.currentOnboardingVersion,
      );
    });

    test('sanitizes unknown enum values and invalid training days', () {
      final restored = UserExperienceProfile.fromJson(<String, dynamic>{
        'capabilities': ['unknown'],
        'trainingGoal': 'invalid',
        'trainingDaysPerWeek': 99,
        'sessionDuration': 'invalid',
        'faithPreference': 'invalid',
        'onboardingVersion': -4,
      });

      expect(restored.capabilities, {UserCapability.athlete});
      expect(restored.trainingGoal, isNull);
      expect(restored.trainingDaysPerWeek, isNull);
      expect(
        restored.sessionDuration,
        SessionDurationPreference.variable,
      );
      expect(restored.faithPreference, FaithContentPreference.undecided);
      expect(restored.onboardingVersion, 0);
    });

    test('migrates existing settings without changing visible faith behavior', () {
      final migrated = UserExperienceProfile.fromLegacySettings(
        const SettingsState(
          weightUnit: WeightUnit.lb,
          workoutRemindersEnabled: true,
          hasCompletedOnboarding: true,
          showDailyVerse: true,
          dailyVerseNotifications: false,
        ),
      );

      expect(migrated.weightUnit, WeightUnit.lb);
      expect(migrated.workoutRemindersWanted, isTrue);
      expect(migrated.faithPreference, FaithContentPreference.enabled);
      expect(migrated.onboardingVersion, 1);
    });

    test('legacy user with faith surfaces disabled stays disabled', () {
      final migrated = UserExperienceProfile.fromLegacySettings(
        const SettingsState(
          showDailyVerse: false,
          dailyVerseNotifications: false,
        ),
      );

      expect(migrated.faithPreference, FaithContentPreference.disabled);
      expect(migrated.faithEnabled, isFalse);
    });

    test('reads legacy faithEnabled JSON when enum is absent', () {
      final enabled = UserExperienceProfile.fromJson(
        <String, dynamic>{'faithEnabled': true},
      );
      final disabled = UserExperienceProfile.fromJson(
        <String, dynamic>{'faithEnabled': false},
      );

      expect(enabled.faithPreference, FaithContentPreference.enabled);
      expect(disabled.faithPreference, FaithContentPreference.disabled);
    });
  });
}
