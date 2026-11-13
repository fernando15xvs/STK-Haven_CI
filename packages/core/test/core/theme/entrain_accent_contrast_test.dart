import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('training text/accent remain readable across 8 accents, dark/light/OLED',
      () {
    for (final accent in AppAccent.values) {
      for (final variant in <(Brightness, bool)>[
        (Brightness.light, false),
        (Brightness.dark, false),
        (Brightness.dark, true),
      ]) {
        final settings = AppearanceSettings(
          accent: accent,
          oledBlack: variant.$2,
        );
        final colors = AppColors.from(settings, variant.$1);
        for (final surface in [
          colors.background, colors.surface, colors.surfaceHigh,
        ]) {
          expect(AppColors.contrast(colors.primary, surface),
              greaterThanOrEqualTo(4.5),
              reason: 'Accento ${accent.name} / ${variant.$1} OLED=${variant.$2}');
          expect(AppColors.contrast(colors.textPrimary, surface),
              greaterThanOrEqualTo(4.5));
          expect(AppColors.contrast(colors.textSecondary, surface),
              greaterThanOrEqualTo(4.5));
        }
        expect(AppColors.contrast(colors.primary, colors.onPrimary),
            greaterThanOrEqualTo(4.5));
      }
    }
  });
}
