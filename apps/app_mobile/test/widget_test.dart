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
  Future<UserExperienceProfile> build() async =>
      const UserExperienceProfile(faithPreference: FaithContentPreference.disabled);
}

void main() {
  test('MyApp remains a valid shared Flutter root widget', () {
    const app = MyApp();
    expect(app, isA<Widget>());
  });

  testWidgets('mobile cold start renders branded splash before opening home',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_SplashSettingsNotifier.new),
          userExperienceProfileProvider.overrideWith(_SplashProfileNotifier.new),
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
