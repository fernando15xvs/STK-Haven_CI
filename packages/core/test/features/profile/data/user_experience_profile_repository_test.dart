import 'dart:io';

import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/data/settings_repository.dart';
import 'package:core/features/profile/data/user_experience_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> box;

  setUpAll(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('stk_haven_experience_profile_');
    Hive.init(tempDirectory.path);
    box = await Hive.openBox<dynamic>('experience_profile_test');
  });

  tearDown(() async {
    await box.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  group('UserExperienceProfileRepository', () {
    test('returns null when profile has not been created', () {
      final repository = UserExperienceProfileRepository(box);

      expect(repository.getStoredProfile(), isNull);
    });

    test('fresh install starts undecided instead of inheriting legacy defaults', () async {
      final repository = UserExperienceProfileRepository(box);

      final profile = await repository.getOrMigrate(const SettingsState());

      expect(profile.faithPreference, FaithContentPreference.undecided);
      expect(profile.faithEnabled, isFalse);
      expect(profile.onboardingVersion, 0);
    });

    test('migrates legacy settings once and persists the result', () async {
      final repository = UserExperienceProfileRepository(box);
      await box.put(SettingsRepository.storageKey, <String, dynamic>{
        'hasCompletedOnboarding': true,
      });
      const settings = SettingsState(
        weightUnit: WeightUnit.lb,
        hasCompletedOnboarding: true,
        showDailyVerse: false,
        dailyVerseNotifications: false,
      );

      final migrated = await repository.getOrMigrate(settings);
      final stored = repository.getStoredProfile();

      expect(migrated.weightUnit, WeightUnit.lb);
      expect(migrated.onboardingVersion, 1);
      expect(migrated.faithPreference, FaithContentPreference.disabled);
      expect(stored?.toJson(), migrated.toJson());
    });

    test('stored profile wins over later legacy setting changes', () async {
      final repository = UserExperienceProfileRepository(box);
      const stored = UserExperienceProfile(
        trainingGoal: TrainingGoal.strength,
        faithPreference: FaithContentPreference.enabled,
        onboardingVersion: 2,
      );
      await repository.saveProfile(stored);

      final loaded = await repository.getOrMigrate(
        const SettingsState(
          showDailyVerse: false,
          dailyVerseNotifications: false,
        ),
      );

      expect(loaded.trainingGoal, TrainingGoal.strength);
      expect(loaded.faithPreference, FaithContentPreference.enabled);
      expect(loaded.onboardingVersion, 2);
    });
  });
}
