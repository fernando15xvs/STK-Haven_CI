import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/shared/app/stk_haven_app.dart';
import 'package:gym_tracker/splash/splash_screen.dart';

class _SplashSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState(hasCompletedOnboarding: true);
}

class _SplashProfileNotifier extends UserExperienceProfileNotifier {
  @override
  Future<UserExperienceProfile> build() async => const UserExperienceProfile(
    faithPreference: FaithContentPreference.disabled,
  );
}

class _LightSplashSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState(
    hasCompletedOnboarding: true,
    appearance: AppearanceSettings(mode: AppThemeMode.light),
  );
}

void main() {
  testWidgets('light-mode splash keeps title and subtitle readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_LightSplashSettingsNotifier.new),
          userExperienceProfileProvider.overrideWith(
            _SplashProfileNotifier.new,
          ),
        ],
        child: const MyApp(),
      ),
    );
    final palette = AppColors.from(
      const AppearanceSettings(mode: AppThemeMode.light),
      Brightness.light,
    );
    for (final label in ['STK Haven', 'Tu compañero de entrenamiento']) {
      final text = tester.widget<Text>(find.text(label));
      expect(
        AppColors.contrast(text.style!.color!, palette.background),
        greaterThanOrEqualTo(4.5),
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  test('MyApp remains a valid shared Flutter root widget', () {
    const app = MyApp();
    expect(app, isA<Widget>());
  });

  testWidgets('mobile cold start renders branded splash before opening home', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_SplashSettingsNotifier.new),
          userExperienceProfileProvider.overrideWith(
            _SplashProfileNotifier.new,
          ),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('STK Haven'), findsOneWidget);
    expect(find.text('Tu compañero de entrenamiento'), findsOneWidget);

    // Disposing before the redirect also ensures splash timers are cancelled.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
