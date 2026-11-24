import 'dart:io';

import 'package:gym_tracker/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B2 D1 Outfit typography is inherited from the shared theme', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme=AppearanceTheme.build(
        const AppearanceSettings(),
        brightness,
      );
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Outfit');
      expect(theme.textTheme.titleMedium?.fontFamily, 'Outfit');
      expect(theme.textTheme.titleMedium?.fontVariations, isNotEmpty);
    }
  });

  test('B2 D1 Nutrition and Food Vision bold weights preserve variable axis', () {
    final source=File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    final overrides=RegExp(
      r'fontWeight:\s*FontWeight\.w(600|800|900)',
    ).allMatches(source).toList();
    expect(overrides.length, greaterThanOrEqualTo(11));
    for (final match in overrides) {
      final weight=match.group(1)!;
      final until=(match.end+100).clamp(0,source.length).toInt();
      final nearby=source.substring(match.end,until);
      expect(
        nearby,
        contains("fontVariations: const [FontVariation('wght', $weight)]"),
        reason:'An Outfit FontWeight override must update the wght axis',
      );
    }
    expect(source, contains('Food Vision'));
    expect(source, contains('Mi plan STK'));
  });
}
