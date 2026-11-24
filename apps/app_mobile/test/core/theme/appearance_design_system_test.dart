import 'dart:convert';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/appearance_theme.dart';
import 'package:gym_tracker/core/theme/app_font_family.dart';
import 'package:gym_tracker/core/theme/app_ui_styles.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';

void main() {
  test('all four variable fonts are registered and locally bundled', () async {
    final manifest = (jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    ) as List).cast<Map<String, dynamic>>();
    final assets = {
      'Outfit': 'assets/fonts/Outfit-Variable.ttf',
      'Inter': 'assets/fonts/Inter-Variable.ttf',
      'Manrope': 'assets/fonts/Manrope-Variable.ttf',
      'Plus Jakarta Sans': 'assets/fonts/PlusJakartaSans-Variable.ttf',
    };
    for (final entry in assets.entries) {
      final record = manifest.firstWhere((item) => item['family'] == entry.key);
      expect((record['fonts'] as List).any((item) =>
          (item as Map)['asset'] == entry.value), isTrue);
      final bytes = await rootBundle.load(entry.value);
      expect(bytes.lengthInBytes, greaterThan(100000));
    }
  });

  for (final style in AppUiStyle.values) {
    for (final font in AppFontFamily.values) {
      testWidgets('${style.name} uses ${font.name} with readable text and card layout', (tester) async {
        final settings = AppearanceSettings(uiStyle: style, fontFamily: font);
        final theme = AppearanceTheme.build(settings, Brightness.dark);
        expect(theme.textTheme.bodyMedium?.fontFamily, appFontFamilyName(font));
        expect(theme.textTheme.bodyMedium?.fontWeight, FontWeight.w500);
        final ui = theme.extension<AppUiTokens>();
        expect(ui, isNotNull);
        expect(ui!.cardRadius, greaterThanOrEqualTo(10));
        expect(ui.buttonRadius, greaterThanOrEqualTo(10));
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(body: Center(child: PremiumCard(
            child: Text('STK Haven', style: AppTypography.bodyLarge),
          ))),
        ));
        final ctx = tester.element(find.text('STK Haven'));
        expect(AppUiTokens.of(ctx).cardRadius, ui.cardRadius);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('classic default keeps Outfit and OLED contrast', () {
    const settings = AppearanceSettings();
    final theme = AppearanceTheme.build(settings, Brightness.dark);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Outfit');
    expect(theme.extension<AppUiTokens>()!.cardRadius, 20);
    final oled = AppColors.from(
      const AppearanceSettings(oledBlack: true),
      Brightness.dark,
    );
    expect(oled.background, Colors.black);
    expect(AppColors.contrast(oled.textPrimary, oled.background),
        greaterThanOrEqualTo(4.5));
  });
}
