import 'dart:io';
import '../../../support/nutrition_page_source.dart';

import 'package:gym_tracker/core/theme/app_palette.dart';
import 'package:gym_tracker/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all eight STK accent colors keep WCAG AA text contrast', () {
    for (final brightness in Brightness.values) {
      for (final oled in <bool>[false, true]) {
        for (final accent in AppAccent.values) {
          final settings=AppearanceSettings(accent:accent,oledBlack:oled);
          final palette=AppColors.from(settings,brightness);
          final description='$brightness / OLED=$oled / $accent';
          for (final background in <Color>[
            palette.background,palette.surface,palette.surfaceHigh,
          ]) {
            expect(AppColors.contrast(palette.primary,background),
              greaterThanOrEqualTo(4.49),reason:description);
            expect(AppColors.contrast(palette.textPrimary,background),
              greaterThanOrEqualTo(4.49),reason:description);
          }
          expect(AppColors.contrast(palette.primary,palette.onPrimary),
            greaterThanOrEqualTo(4.49),reason:description);
          final theme=AppearanceTheme.build(settings,brightness);
          expect(theme.colorScheme.primary,palette.primary,
            reason:description);
          expect(theme.textTheme.bodyMedium?.fontWeight,FontWeight.w500,
            reason:description);
          expect(theme.textTheme.labelMedium?.fontWeight,FontWeight.w600,
            reason:description);
        }
      }
    }
  });

  test('nutrition status and error copy inherit the global Outfit text theme',(){
    final source=readNutritionPageSource(File('lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart'));
    expect(source,contains('Theme.of(context).textTheme.bodyMedium?.copyWith('));
    expect(source,isNot(contains('style: TextStyle(color: colors.error)')));
    expect(source,isNot(contains('style: TextStyle(color: colors.onSurfaceVariant)')));
  });
}