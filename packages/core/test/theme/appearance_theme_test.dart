import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core/theme/app_palette.dart';
import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/settings_state.dart';

void main() {
  test('every accent has readable text and button contrast in both modes', () {
    for (final accent in AppAccent.values) {
      for (final brightness in Brightness.values) {
        final p = AppColors.from(
          AppearanceSettings(accent: accent),
          brightness,
        );
        for (final bg in [p.background, p.surface, p.surfaceHigh]) {
          for (final fg in [p.primary, p.textPrimary, p.textSecondary]) {
            expect(
              AppColors.contrast(fg, bg),
              greaterThanOrEqualTo(4.5),
              reason: '$accent $brightness $fg / $bg',
            );
          }
        }
        expect(
          AppColors.contrast(p.primary, p.onPrimary),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });
  test('preferences round trip and old backups keep dark blue defaults', () {
    expect(SettingsState.fromJson({}).appearance.mode, AppThemeMode.dark);
    final state = const SettingsState().copyWith(
      appearance: const AppearanceSettings(
        mode: AppThemeMode.system,
        accent: AppAccent.emerald,
        oledBlack: true,
        cardStyle: AppCardStyle.flat,
      ),
    );
    final restored = SettingsState.fromJson(state.toJson()).appearance;
    expect(restored.toJson(), state.appearance.toJson());
    expect(
      AppearanceSettings.fromJson({'mode': 'invalid', 'accent': 3}).accent,
      AppAccent.blue,
    );
    expect(AppearanceTheme.mode(restored.mode), ThemeMode.system);
  });
  test('OLED only changes dark background, flat removes card shadows', () {
    const settings = AppearanceSettings(
      oledBlack: true,
      cardStyle: AppCardStyle.flat,
    );
    expect(AppColors.from(settings, Brightness.dark).background, Colors.black);
    expect(
      AppColors.from(settings, Brightness.light).background,
      isNot(Colors.black),
    );
    expect(AppColors.from(settings, Brightness.dark).shadows, isEmpty);
    expect(
      AppearanceTheme.build(settings, Brightness.light).cardTheme.elevation,
      0,
    );
  });
  testWidgets(
    'system changes and accents rebuild existing descendants without resetting state',
    (tester) async {
      final mode = ValueNotifier(AppThemeMode.system);
      final accent = ValueNotifier(AppAccent.blue);
      addTearDown(mode.dispose);
      addTearDown(accent.dispose);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: Listenable.merge([mode, accent]),
          builder: (context, _) {
            final settings = AppearanceSettings(
              mode: mode.value,
              accent: accent.value,
            );
            return MaterialApp(
              theme: AppearanceTheme.build(settings, Brightness.light),
              darkTheme: AppearanceTheme.build(settings, Brightness.dark),
              themeMode: AppearanceTheme.mode(mode.value),
              themeAnimationDuration: Duration.zero,
              home: const _Sample(),
            );
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'Sesión en curso');
      final before = tester
          .widget<ColoredBox>(find.byKey(const Key('surface')))
          .color;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        tester.widget<ColoredBox>(find.byKey(const Key('surface'))).color,
        isNot(before),
      );
      accent.value = AppAccent.rose;
      await tester.pumpAndSettle();
      expect(find.text('Sesión en curso'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byKey(const Key('accent'))).color,
        AppColors.from(
          const AppearanceSettings(accent: AppAccent.rose),
          Brightness.dark,
        ).primary,
      );
    },
  );
}

class _Sample extends StatelessWidget {
  const _Sample();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ColoredBox(
      key: const Key('surface'),
      color: AppColors.of(context).background,
      child: Column(
        children: [
          const TextField(),
          Icon(
            Icons.star,
            key: const Key('accent'),
            color: AppColors.of(context).primary,
          ),
        ],
      ),
    ),
  );
}
