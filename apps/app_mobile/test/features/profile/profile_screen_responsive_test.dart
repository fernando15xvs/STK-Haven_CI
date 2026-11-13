import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/profile/presentation/pages/profile_page.dart';

class _FakeSettings extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();
}

class _FakeExperience extends UserExperienceProfileNotifier {
  @override
  Future<UserExperienceProfile> build() async => const UserExperienceProfile(
    displayName: 'Una persona que practica entrenamiento de fuerza',
    trainingGoal: TrainingGoal.hypertrophy,
    trainingExperience: TrainingExperience.intermediate,
  );
}

void main() {
  testWidgets('Profile uses scrollable groups at 320/390/430 and 100/160/200%',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in <double>[320, 390, 430]) {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      for (final scale in <double>[1, 1.6, 2]) {
        for (final variant in <(Brightness, bool)>[
          (Brightness.light, false),
          (Brightness.dark, false),
          (Brightness.dark, true),
        ]) {
          await tester.pumpWidget(ProviderScope(
            overrides: [
              settingsProvider.overrideWith(_FakeSettings.new),
              userExperienceProfileProvider.overrideWith(_FakeExperience.new),
            ],
            child: MaterialApp(
              theme: AppearanceTheme.build(
                AppearanceSettings(oledBlack: variant.$2), variant.$1,
              ),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const ProfilePage(),
              ),
            ),
          ));
          await tester.pumpAndSettle();
          expect(find.byType(ProfilePage), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: '$width dp / $scale text / ${variant.$1} / OLED ${variant.$2}');
        }
      }
    }
  });
}
