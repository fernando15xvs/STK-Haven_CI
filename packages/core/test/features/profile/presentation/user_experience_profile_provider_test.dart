import 'dart:io';

import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
