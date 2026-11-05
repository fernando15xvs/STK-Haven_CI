import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_consistency_metrics.dart';

void main() {
  for (final brightness in [Brightness.dark, Brightness.light]) {
    testWidgets('consistency summary has no duplicate active days in ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final colors = AppColors.from(
        AppearanceSettings(oledBlack: brightness == Brightness.dark),
        brightness,
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness, extensions: [colors]),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.6),
            ),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: ProgressConsistencyMetrics(
                workoutsPerWeek: 2.5,
                averageSessionMinutes: 252,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('ENTRENOS / SEM'), findsOneWidget);
      expect(find.text('MEDIA REGISTRADA'), findsOneWidget);
      expect(find.text('DÍAS ACTIVOS'), findsNothing);
      expect(find.text('2.5'), findsOneWidget);
      expect(find.text('252m'), findsOneWidget);
      for (final number in ['2.5', '252m']) {
        final text = tester.widget<Text>(find.text(number));
        expect(text.style?.fontFamily, 'Outfit');
        expect(text.style?.color, colors.textPrimary);
        expect(
          text.style?.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason: '$number must keep digits aligned without a new font',
        );
        expect(
          AppColors.contrast(text.style!.color!, colors.surfaceHigh),
          greaterThanOrEqualTo(4.5),
          reason: 'Dark and light numeric text must be legible',
        );
      }
      expect(find.byType(Tooltip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
