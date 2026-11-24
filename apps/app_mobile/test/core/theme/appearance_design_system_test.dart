import 'dart:convert';
import 'dart:io';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/compact_progress_period_selector.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/appearance_theme.dart';
import 'package:gym_tracker/core/theme/app_font_family.dart';
import 'package:gym_tracker/core/theme/app_ui_styles.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/core/theme/components/metric_tile.dart';
import 'package:gym_tracker/core/theme/app_text_scaler.dart';
import 'package:gym_tracker/features/profile/presentation/widgets/profile_section_card.dart';

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

  testWidgets('progress period selector inherits every selected family', (tester) async {
    for (final font in AppFontFamily.values) {
      final settings = AppearanceSettings(fontFamily: font, uiStyle: AppUiStyle.compact);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: AppearanceTheme.build(settings, Brightness.dark),
          home: const Scaffold(body: Center(child: CompactProgressPeriodSelector())),
        ),
      ));
      await tester.pumpAndSettle();
      final label = tester.widget<Text>(find.text(TimeFilter.month.label));
      expect(label.style?.fontFamily, appFontFamilyName(font));
      expect(tester.getSize(find.byKey(const ValueKey('progress_shared_period'))).height,
          greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    }
  });

  test('production Mobile text styles do not hardcode font families', () {
    final root = Directory('lib');
    expect(root.existsSync(), isTrue);
    final violations = <String>[];
    final fixedFont = RegExp(r"""fontFamily\s*:\s*['"]""");
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (fixedFont.hasMatch(file.readAsStringSync())) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty, reason: 'Use the selected Material theme family');
  });

  test('user text preference composes with nonlinear accessibility scaling', () {
    const platform = _NonlinearFixture();
    expect(combineAppTextScale(platform, 1), same(platform));
    final scaled = combineAppTextScale(platform, 1.25);
    expect(scaled.scale(12), platform.scale(12) * 1.25);
    expect(scaled.scale(28), platform.scale(28) * 1.25);
    expect(scaled, combineAppTextScale(platform, 1.25));
  });

  for (final style in AppUiStyle.values) {
    testWidgets('shared metric and Profile card geometry: ${style.name}', (tester) async {
      final settings = AppearanceSettings(uiStyle: style);
      final ui = AppUiTokens.from(style);
      await tester.pumpWidget(MaterialApp(
        theme: AppearanceTheme.build(settings, Brightness.light),
        home: const Scaffold(body: SingleChildScrollView(child: Column(children: [
          MetricTile(label: 'Sesiones completadas', value: '12'),
          ProfileSectionCard(title: 'Preferencias', children: [Text('Datos')]),
        ]))),
      ));
      final metric = find.descendant(
        of: find.byType(MetricTile), matching: find.byType(Container)).first;
      final box = tester.widget<Container>(metric).decoration! as BoxDecoration;
      expect(box.borderRadius, BorderRadius.circular(ui.cardRadius));
      final card = tester.widget<AnimatedContainer>(find.descendant(
        of: find.byType(ProfileSectionCard), matching: find.byType(AnimatedContainer)).first);
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(ui.cardRadius));
      expect(tester.takeException(), isNull);
    });
  }
}

class _NonlinearFixture extends TextScaler {
  const _NonlinearFixture();

  @override
  double scale(double fontSize) => fontSize * (fontSize < 16 ? 2 : 1.5);

  @override
  double get textScaleFactor => 2;
}
