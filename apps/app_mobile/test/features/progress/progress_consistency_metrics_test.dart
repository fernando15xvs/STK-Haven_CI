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
  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        testWidgets(
          'consistency reflows without ellipsis at ${width.toInt()}px '
          '/ ${scale.toStringAsFixed(1)} / ${brightness.name}',
          (tester) async {
            tester.view.physicalSize = Size(width, 850);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final handle = tester.ensureSemantics();
            try {
              final colors = AppColors.from(
                AppearanceSettings(
                  accent: AppAccent.rose,
                  oledBlack: brightness == Brightness.dark,
                ),
                brightness,
              );
              await tester.pumpWidget(MaterialApp(
                theme: ThemeData(
                  brightness: brightness,
                  fontFamily: 'Outfit',
                  extensions: [colors],
                ),
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(
                      textScaler: TextScaler.linear(scale)),
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
              final week = find.byKey(
                  const ValueKey('consistency_weekly_tile'));
              final duration = find.byKey(
                  const ValueKey('consistency_duration_tile'));
              expect(week, findsOneWidget);
              expect(duration, findsOneWidget);
              expect(find.bySemanticsLabel(
                  'Entrenamientos por semana: 2.5'), findsOneWidget);
              expect(find.bySemanticsLabel(
                  'Duración media registrada: 252 minutos'),
                  findsOneWidget);
              expect(find.text('MEDIA REGISTRADA'), findsOneWidget);
              expect(find.text('252m'), findsOneWidget);
              expect(
                tester.widget<Text>(find.text('252m')).maxLines,
                isNull,
                reason: 'Real numbers must never be shortened with ellipsis',
              );
              final weekSize = tester.getSize(week);
              expect(weekSize.width, lessThanOrEqualTo(width - 48));
              if (width == 320 && scale == 1.6) {
                expect(tester.getTopLeft(duration).dy,
                    greaterThan(tester.getTopLeft(week).dy));
              }
              if (width == 430 && scale == 1.0) {
                expect(tester.getTopLeft(duration).dy,
                    tester.getTopLeft(week).dy);
              }
              expect(tester.takeException(), isNull);
            } finally {
              handle.dispose();
            }
          },
        );
      }
    }
  }

}
