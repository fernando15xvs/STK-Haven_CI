import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/gamification_state.dart';
import 'package:core/features/profile/application/gamification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/profile/presentation/pages/achievements_page.dart';

class _AchievementsFixture extends GamificationNotifier {
  @override
  GamificationState build() => const GamificationState(
    xp: 175,
    level: 2,
    achievements: [
      Achievement(
        id: 'new',
        title: 'Primera sesión',
        description: 'Completa tu primera sesión registrada.',
        progress: 0.75,
      ),
      Achievement(
        id: 'advanced',
        title: 'Consistencia en entrenamientos de larga duración',
        description: 'Completa sesiones de entrenamiento durante varias semanas seguidas, '
            'manteniendo un buen registro de tus series, repeticiones y descansos.',
        progress: 0.4,
      ),
    ],
  );
}

void main() {
  testWidgets('badges fit 320/390/430dp, text 100/160/200% in dark/light/OLED',
      (tester) async {
    for (final width in <double>[320, 390, 430]) {
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      for (final scale in <double>[1, 1.6, 2]) {
        for (final variant in <(Brightness, bool)>[
          (Brightness.light, false),
          (Brightness.dark, false),
          (Brightness.dark, true),
        ]) {
          final theme = AppearanceTheme.build(
            AppearanceSettings(oledBlack: variant.$2),
            variant.$1,
          );
          await tester.pumpWidget(ProviderScope(
            overrides: [
              gamificationProvider.overrideWith(_AchievementsFixture.new),
            ],
            child: MaterialApp(
              theme: theme,
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const AchievementsPage(),
              ),
            ),
          ));
          expect(find.byType(AchievementsPage), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: '$width dp, $scale text, ${variant.$1}, OLED ${variant.$2}');
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
