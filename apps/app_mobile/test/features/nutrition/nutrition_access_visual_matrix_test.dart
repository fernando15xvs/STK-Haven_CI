import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/features/nutrition/application/nutrition_access_state.dart';
import 'package:core/features/nutrition/presentation/pages/nutrition_intelligence_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _nutritionPanel({
  required AppearanceSettings appearance,
  required Brightness brightness,
  required NutritionAccessState access,
  required double textScale,
  VoidCallback? refresh,
}) {
  return MaterialApp(
    theme: AppearanceTheme.build(appearance, brightness),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Builder(
              builder: (context) => RepaintBoundary(
                key: const ValueKey('nutrition_qa_capture'),
                child: NutritionAccessStatusPanel(
                  colors: Theme.of(context).colorScheme,
                  access: access,
                  onRefreshAdultAccess: refresh,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Capture real Outfit glyphs instead of Flutter test's Ahem font.
    final loader = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/fonts/Outfit-Variable.ttf'));
    await loader.load();
  });

  testWidgets('B3 Nutrition access: 216 layouts, 4 safety states and 24 QA PNGs',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final artifactDir = Directory('build/nutrition_access_visual_qa')
      ..createSync(recursive: true);
    var screenshots = 0;
    final coveredStates = <NutritionAccessState>{};
    for (final width in <double>[320, 390, 430]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      for (final scale in <double>[1, 1.6, 2]) {
        for (final theme in const <(Brightness, bool)>[
          (Brightness.light, false),
          (Brightness.dark, false),
          (Brightness.dark, true),
        ]) {
          for (final accent in AppAccent.values) {
            final stateIndex = (accent.index + width.toInt() + 
                (scale * 10).toInt() + (theme.$2 ? 2 : 0) +
                (theme.$1 == Brightness.dark ? 1 : 0)) % 
                NutritionAccessState.values.length;
            final access = NutritionAccessState.values[stateIndex];
            coveredStates.add(access);
            final appearance = AppearanceSettings(
              accent: accent,
              oledBlack: theme.$2,
            );
            await tester.pumpWidget(_nutritionPanel(
              appearance: appearance,
              brightness: theme.$1,
              access: access,
              textScale: scale,
              refresh: () {},
            ));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('nutrition_access_state_panel')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('nutrition_how_it_works')),
              findsOneWidget,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'width=$width text=$scale brightness=${theme.$1} '
                  'oled=${theme.$2} accent=$accent access=$access',
            );
            // No calorie goals are shown on a non-verified access panel.
            if (!access.canViewNumericNutrition) {
              expect(find.textContaining('kcal/día'), findsNothing);
            }
            if (access != NutritionAccessState.adultUnverified) {
              expect(find.text('Volver a comprobar acceso'), findsNothing);
            }
            // 3 themes x 8 accents = 24 real rendered, synthetic PNGs.
            if (width == 390 && scale == 1.6) {
              await tester.runAsync(() async {
                final boundary = tester.renderObject<RenderRepaintBoundary>(
                  find.byKey(const ValueKey('nutrition_qa_capture')),
                );
                final image = await boundary.toImage(pixelRatio: 2);
                try {
                  final bytes = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  expect(bytes, isNotNull);
                  final themeName = theme.$2
                      ? 'oled'
                      : theme.$1 == Brightness.dark ? 'dark' : 'light';
                  final file = File(
                    '${artifactDir.path}/nutrition_${themeName}_'
                    '${accent.name}_${access.name}.png',
                  );
                  file.writeAsBytesSync(bytes!.buffer.asUint8List(
                    bytes.offsetInBytes,
                    bytes.lengthInBytes,
                  ));
                  expect(file.lengthSync(), greaterThan(1000));
                  screenshots++;
                } finally {
                  image.dispose();
                }
              });
            }
          }
        }
      }
    }
    expect(coveredStates, NutritionAccessState.values.toSet());
    expect(screenshots, 24);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('B3 minor and unverified guidance can expand at 320dp 200%',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    var requestedRefreshes = 0;
    for (final access in [
      NutritionAccessState.minor,
      NutritionAccessState.ageUnknown,
      NutritionAccessState.adultUnverified,
    ]) {
      await tester.pumpWidget(_nutritionPanel(
        appearance: const AppearanceSettings(),
        brightness: Brightness.dark,
        access: access,
        textScale: 2,
        refresh: () => requestedRefreshes++,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('¿Cómo funciona?'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$access');
      if (access == NutritionAccessState.minor) {
        expect(find.textContaining('no habilitamos metas calóricas'), findsOneWidget);
      } else {
        expect(find.textContaining('Food Vision'), findsWidgets);
      }
      if (access == NutritionAccessState.adultUnverified) {
        final refresh = find.text('Volver a comprobar acceso');
        await tester.ensureVisible(refresh);
        await tester.tap(refresh);
        await tester.pumpAndSettle();
        expect(requestedRefreshes, 1);
      } else {
        expect(find.text('Volver a comprobar acceso'), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}
