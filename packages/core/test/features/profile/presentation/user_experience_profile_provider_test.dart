import 'dart:io';

import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> metadataBox;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'stk_haven_experience_provider_',
    );
    Hive.init(tempDirectory.path);
    metadataBox = await Hive.openBox<dynamic>(HiveBoxes.metadata);
  });

  tearDown(() async {
    await metadataBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('unified editor keeps independent verse visibility and saves Home choices', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(userExperienceProfileProvider.notifier);
    final initial = await container.read(userExperienceProfileProvider.future);
    // No native notification call: edit while Faith is already enabled.
    final enabled = initial.copyWith(faithPreference: FaithContentPreference.enabled);
    await notifier.updateProfile(enabled);
    final settings = container.read(settingsProvider.notifier);
    await settings.persistProfileDailyVerseVisibility(false);
    final edited = await notifier.saveProfileEdit(original: enabled,
      draft: enabled.copyWith(habitsEnabled: true, showSleepOnHome: false));
    expect(edited.habitsEnabled, isTrue);
    expect(edited.showSleepOnHome, isFalse);
    expect(container.read(settingsProvider).showDailyVerse, isFalse);
    final hidden = edited.copyWith(faithPreference: FaithContentPreference.disabled);
    await notifier.updateProfile(hidden);
    await notifier.saveProfileEdit(original: hidden,
      draft: hidden.copyWith(faithPreference: FaithContentPreference.enabled));
    expect(container.read(settingsProvider).showDailyVerse, isFalse);
    await notifier.saveProfileEdit(original: container.read(userExperienceProfileProvider).value!,
      draft: container.read(userExperienceProfileProvider).value!, showDailyVerse: true);
    expect(container.read(settingsProvider).showDailyVerse, isTrue);
  });

  test(
    'settings changes do not rebuild profile into LateInitializationError',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial =
          await container.read(userExperienceProfileProvider.future);
      expect(initial.weightUnit, WeightUnit.kg);

      container
          .read(settingsProvider.notifier)
          .setWeightUnit(WeightUnit.lb);
      await Future<void>.delayed(Duration.zero);

      final profileAfterSettingsChange =
          await container.read(userExperienceProfileProvider.future);

      expect(
        container.read(userExperienceProfileProvider).hasError,
        isFalse,
      );
      expect(profileAfterSettingsChange.weightUnit, WeightUnit.kg);
    },
  );
}
