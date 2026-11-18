import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/features/nutrition/application/stk_age_aware_nutrition_plans.dart';
import 'package:core/features/nutrition/presentation/widgets/stk_mobile_nutrition_goal_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/fonts/Outfit-Variable.ttf'));
    await loader.load();
  });

  testWidgets('mobile goal selector: 216 accessible Outfit layouts and 24 PNGs',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dir = Directory('build/stk_mobile_nutrition_goals_visual_qa')
      ..createSync(recursive: true);
    const audiences = [
      StkNutritionAudience.teen15To17,
      StkNutritionAudience.adultDeclared,
      StkNutritionAudience.adultVerified,
      StkNutritionAudience.unknownAge,
    ];
    var checked = 0;
    var captures = 0;

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
            final appearance = AppearanceSettings(
              accent: accent,
              oledBlack: theme.$2,
            );
            final audience = audiences[
                (accent.index + width.toInt() + scale.toInt()) %
                    audiences.length];
            final selected =
                StkNutritionIntent.values[accent.index % 3];

            await tester.pumpWidget(MaterialApp(
              theme: AppearanceTheme.build(appearance, theme.$1),
              home: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Builder(
                      builder: (context) => RepaintBoundary(
                        key: const ValueKey(
                          'stk_mobile_nutrition_goal_capture',
                        ),
                        // RepaintBoundary alone is transparent. Capture
                        // the ACTUAL themed surface, not a misleading black
                        // background in external PNG viewers.
                        child: ColoredBox(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: StkMobileNutritionGoalSelector(
                              audience: audience,
                              selected: selected,
                              onSelected: (_) {},
                              onOpenAdultPlanner: () {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ));
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull,
                reason: 'width=$width scale=$scale brightness=${theme.$1} '
                    'OLED=${theme.$2} accent=$accent audience=$audience');
            expect(
              find.byKey(const ValueKey('stk_mobile_nutrition_goal_selector')),
              findsOneWidget,
            );
            checked++;

            if (width == 390 && scale == 1.6) {
              await tester.runAsync(() async {
                final boundary = tester.renderObject<RenderRepaintBoundary>(
                  find.byKey(
                    const ValueKey('stk_mobile_nutrition_goal_capture'),
                  ),
                );
                final image = await boundary.toImage(pixelRatio: 2);
                try {
                  final bytes = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  expect(bytes, isNotNull);
                  final mode = theme.$2
                      ? 'oled'
                      : theme.$1 == Brightness.dark ? 'dark' : 'light';
                  final file = File(
                    '${dir.path}/goal_${mode}_${accent.name}.png',
                  );
                  final data = bytes!;
                  file.writeAsBytesSync(data.buffer.asUint8List(
                    data.offsetInBytes,
                    data.lengthInBytes,
                  ));
                  expect(file.lengthSync(), greaterThan(1000));
                  captures++;
                } finally {
                  image.dispose();
                }
              });
            }
          }
        }
      }
    }
    expect(checked, 3 * 3 * 3 * AppAccent.values.length);
    expect(captures, 3 * AppAccent.values.length);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
