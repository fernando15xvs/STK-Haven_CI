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
  _ProfileFixture({this.consent = false});
  final bool consent;

  @override
  Future<UserExperienceProfile> build() async => UserExperienceProfile(
    displayName: 'Perfil de prueba',
    trainingGoal: TrainingGoal.hypertrophy,
    trainingExperience: TrainingExperience.intermediate,
    trainingDaysPerWeek: 4,
    trainingEnvironment: TrainingEnvironment.fullGym,
    sessionDuration: SessionDurationPreference.minutes60,
    dateOfBirth: DateTime(1995, 5, 12),
    genderIdentity: GenderIdentity.nonBinary,
    optionalDemographicsConsented: consent,
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
    expect(find.text('Fecha de nacimiento'), findsNothing);
    expect(find.text('Género'), findsNothing);
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

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      for (final surface in ['light', 'dark', 'oled']) {
      testWidgets('Perfil y Ajustes are reachable at $width dp / $scale text / $surface', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 840);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            settingsProvider.overrideWith(_SettingsFixture.new),
            userExperienceProfileProvider.overrideWith(() => _ProfileFixture(consent: true)),
            gamificationProvider.overrideWith(_GamificationFixture.new),
          ],
          child: MaterialApp(
            theme: AppearanceTheme.build(
              AppearanceSettings(oledBlack: surface == 'oled'),
              surface == 'light' ? Brightness.light : Brightness.dark,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const ProfilePage(),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Perfil de prueba'), findsOneWidget);
        expect(find.text('Editar perfil'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Fecha de nacimiento'), 150);
        expect(find.text('Fecha de nacimiento'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Género'), 150);
        expect(find.text('Género'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('profile_open_settings')));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileSettingsPage), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Legal y privacidad'), 180);
        expect(find.text('Legal y privacidad'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
      }
    }
  }
}
