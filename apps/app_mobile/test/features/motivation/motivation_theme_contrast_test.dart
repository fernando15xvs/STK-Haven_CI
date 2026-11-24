import 'package:gym_tracker/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B2 all eight accents keep WCAG AA normal-text contrast in three themes',
      () {
    for (final accent in AppAccent.values) {
      for (final theme in const <(Brightness, bool)>[
        (Brightness.light, false),
        (Brightness.dark, false),
        (Brightness.dark, true),
      ]) {
        final colors = AppColors.from(
          AppearanceSettings(accent: accent, oledBlack: theme.$2),
          theme.$1,
        );
        final surfaces = [
          colors.background,
          colors.surface,
          colors.surfaceHigh,
        ];
        for (final background in surfaces) {
          expect(
            AppColors.contrast(colors.primary, background),
            greaterThanOrEqualTo(4.49),
            reason: 'accent=$accent theme=$theme on surface=$background',
          );
          expect(
            AppColors.contrast(colors.textPrimary, background),
            greaterThanOrEqualTo(4.49),
            reason: 'primary text accent=$accent theme=$theme',
          );
          expect(
            AppColors.contrast(colors.textSecondary, background),
            greaterThanOrEqualTo(4.49),
            reason: 'secondary text accent=$accent theme=$theme',
          );
        }
        expect(
          AppColors.contrast(colors.onPrimary, colors.primary),
          greaterThanOrEqualTo(4.49),
          reason: 'primary button accent=$accent theme=$theme',
        );
      }
    }
  });
}
