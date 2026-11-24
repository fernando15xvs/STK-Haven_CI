import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/gamification_state.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/application/gamification_provider.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/theme/appearance_theme.dart';
import 'package:gym_tracker/features/profile/presentation/pages/profile_page.dart';
import 'package:gym_tracker/features/profile/presentation/pages/profile_settings_page.dart';
import 'package:gym_tracker/features/profile/presentation/widgets/profile_avatar.dart';

class _SettingsFixture extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState(
    hasCompletedOnboarding: true,
    appearance: AppearanceSettings(mode: AppThemeMode.system),
  );

  @override
  Future<void> setAppearance(AppearanceSettings appearance) async {
    state = state.copyWith(appearance: appearance);
  }
}

class _ProfileFixture extends UserExperienceProfileNotifier {
  @override
  Future<UserExperienceProfile> build() async => const UserExperienceProfile(
    displayName: 'Perfil de prueba',
    trainingGoal: TrainingGoal.hypertrophy,
    trainingExperience: TrainingExperience.intermediate,
    trainingDaysPerWeek: 4,
    trainingEnvironment: TrainingEnvironment.fullGym,
    sessionDuration: SessionDurationPreference.minutes60,
  );
}

class _GamificationFixture extends GamificationNotifier {
  @override
  GamificationState build() => const GamificationState(
    xp: 250,
    level: 2,
    achievements: [
      Achievement(
        id: 'first',
        title: 'Primera sesión',
        description: 'Primera medalla',
      ),
    ],
  );
}

void main() {
  testWidgets('Perfil displays stored values and large photo before editing', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_SettingsFixture.new),
        userExperienceProfileProvider.overrideWith(_ProfileFixture.new),
        gamificationProvider.overrideWith(_GamificationFixture.new),
      ],
      child: MaterialApp(
        theme: AppearanceTheme.build(const AppearanceSettings(), Brightness.dark),
        home: const ProfilePage(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Perfil de prueba'), findsOneWidget);
    expect(tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).radius, 54);
    expect(find.text('Editar perfil'), findsOneWidget);
    expect(find.text('Ganar músculo'), findsWidgets);
    expect(find.text('Intermedio'), findsWidgets);
    expect(find.text('4 días'), findsWidgets);
    expect(find.byKey(const ValueKey('profile_open_settings')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile_open_settings')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSettingsPage), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('PREFERENCIAS'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings_quick_light')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings_quick_dark')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings_quick_light')));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ProfileSettingsPage));
    final container = ProviderScope.containerOf(context);
    expect(container.read(settingsProvider).appearance.mode, AppThemeMode.light);
    expect(container.read(settingsProvider).hasCompletedOnboarding, isTrue);
  });
}
