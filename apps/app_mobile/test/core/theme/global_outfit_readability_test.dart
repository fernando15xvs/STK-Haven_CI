import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/theme/app_colors.dart' as mobile;

void main() {
  test('the mobile typography scale keeps Outfit and readable minimums', () {
    for (final style in <TextStyle>[
      mobile.AppTypography.bodyLarge,
      mobile.AppTypography.bodyMedium,
      mobile.AppTypography.bodySmall,
      mobile.AppTypography.labelLarge,
      mobile.AppTypography.labelMedium,
      mobile.AppTypography.labelSmall,
      mobile.AppTypography.headlineSmall,
      mobile.AppTypography.monoMedium,
    ]) {
      expect(style.fontFamily, 'Outfit');
      expect(style.fontSize, greaterThanOrEqualTo(12));
      expect(style.fontWeight!.index,
          greaterThanOrEqualTo(FontWeight.w500.index));
      final axis = style.fontVariations;
      expect(axis, isNotNull, reason: 'Variable Outfit must set wght on Flutter 3.38');
      expect(axis, hasLength(1));
      expect(axis!.single.axis, 'wght');
      expect(axis.single.value, (style.fontWeight!.index + 1) * 100);

    }
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final accent in AppAccent.values) {
      test('Material typography and secondary text contrast: '
          '${brightness.name} / ${accent.name}', () {
        final settings = AppearanceSettings(
          accent: accent,
          oledBlack: brightness == Brightness.dark,
        );
        final theme = AppearanceTheme.build(settings, brightness);
        final colors = AppColors.from(settings, brightness);
        final typography = theme.textTheme;
        for (final style in <TextStyle?>[
          typography.bodyLarge,
          typography.bodyMedium,
          typography.bodySmall,
          typography.labelLarge,
          typography.labelMedium,
          typography.labelSmall,
          typography.titleSmall,
          typography.titleMedium,
          typography.titleLarge,
        ]) {
          expect(style, isNotNull);
          expect(style!.fontFamily, 'Outfit');
          expect(style.fontWeight!.index,
              greaterThanOrEqualTo(FontWeight.w500.index));
          expect(style.fontVariations, isNotNull,
              reason: 'ThemeData typography must render actual variable weight');
          expect(style.fontVariations!.single.axis, 'wght');
          expect(style.fontVariations!.single.value,
              (style.fontWeight!.index + 1) * 100);

        }
        for (final bg in <Color>[
          colors.background,
          colors.surface,
          colors.surfaceHigh,
        ]) {
          expect(AppColors.contrast(colors.textSecondary, bg),
              greaterThanOrEqualTo(4.5),
              reason: 'Secondary labels must remain legible on every surface');
        }
      });
    }
  }
}
