import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/exercises/presentation/pages/exercise_detail_page.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_chart_style.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/volume_chart.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('es'));

  final volume = [
    VolumeDataPoint(DateTime(2026, 10, 1), 2800),
    VolumeDataPoint(DateTime(2026, 10, 15), 15912),
    VolumeDataPoint(DateTime(2026, 10, 31), 2900),
  ];
  final strength = [
    ExerciseProgressPoint(date: DateTime(2026, 10, 1), value: 37.7),
    ExerciseProgressPoint(date: DateTime(2026, 10, 15), value: 39.0),
    ExerciseProgressPoint(date: DateTime(2026, 10, 31), value: 38.9),
  ];

  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('both chart touch extrema at ${width.toInt()}px '
            '${brightness.name} scale=$scale', (tester) async {
          tester.view.physicalSize = Size(width, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final colors = AppColors.from(
            AppearanceSettings(
              accent: AppAccent.emerald,
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
                  size: Size(width, 850),
                  textScaler: TextScaler.linear(scale),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        VolumeChart(data: volume, weightUnit: WeightUnit.kg),
                        const SizedBox(height: 20),
                        ExerciseOneRmChart(
                          data: strength,
                          weightUnit: WeightUnit.kg,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ));
          await tester.pumpAndSettle();

          final charts = tester.widgetList<LineChart>(
            find.byType(LineChart),
          ).toList(growable: false);
          expect(charts, hasLength(2));
          for (final chart in charts) {
            final plot = chart.data;
            final bar = plot.lineBarsData.single;
            final touch = plot.lineTouchData;
            final tip = touch.touchTooltipData;
            expect(touch.enabled, isTrue);
            expect(tip.fitInsideHorizontally, isTrue);
            expect(tip.fitInsideVertically, isTrue);
            expect(tip.tooltipMargin, ProgressChartStyle.tooltipMargin);
            expect(tip.maxContentWidth,
                ProgressChartStyle.tooltipMaxContentWidth);
            final guides = touch.getTouchedSpotIndicator(bar, [0, 1, 2]);
            expect(guides, hasLength(3));
            for (final guide in guides) {
              expect(guide, isNotNull);
              expect(guide!.indicatorBelowLine.strokeWidth, greaterThan(0));
              expect(guide.touchedSpotDotData.show, isTrue);
            }
            for (final index in [0, 1, 2]) {
              final tipItems = tip.getTooltipItems([
                LineBarSpot(bar, 0, bar.spots[index]),
              ]);
              expect(tipItems, hasLength(1));
              expect(tipItems.single, isNotNull);
              final label = tipItems.single!.text;
              expect(label, contains('2026'));
              expect(label, contains('kg'));
              expect(label, isNot(contains('15912.0')));
              expect(tipItems.single!.textStyle.fontFamily, 'Outfit');
            }
            final maxSpot = bar.spots
                .reduce((a, b) => a.y >= b.y ? a : b);
            expect(plot.maxY, greaterThan(maxSpot.y));
            expect(plot.minY, lessThan(bar.spots
                .map((spot) => spot.y).reduce((a, b) => a < b ? a : b)));
            expect(plot.maxX, greaterThan(bar.spots.last.x));
            expect(plot.minX, lessThan(bar.spots.first.x));
          }

          // The e1RM maximum/minimum are readable without covering the plot.
          expect(find.text('Mín. 37,7 kg'), findsOneWidget);
          expect(find.text('Máx. 39 kg'), findsOneWidget);
          for (final text in ['1 oct', '31 oct', 'Mín. 37,7 kg', 'Máx. 39 kg']) {
            final finder = find.text(text).last;
            final rect = tester.getRect(finder);
            expect(rect.left, greaterThanOrEqualTo(0), reason: text);
            expect(rect.right, lessThanOrEqualTo(width), reason: text);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('lb e1RM extrema and last-date tooltip fit 320px at 160%',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: ExerciseOneRmChart(
            data: strength,
            weightUnit: WeightUnit.lb,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final values = tester.widget<LineChart>(find.byType(LineChart)).data;
    final labels = values.lineTouchData.touchTooltipData.getTooltipItems([
      LineBarSpot(
        values.lineBarsData.single,
        0,
        values.lineBarsData.single.spots.last,
      ),
    ]);
    expect(labels.single!.text, contains('31 oct 2026'));
    expect(labels.single!.text, contains('lb'));
    expect(find.textContaining('Mín.'), findsOneWidget);
    expect(find.textContaining('Máx.'), findsOneWidget);
    for (final finder in [
      find.textContaining('Mín.'),
      find.textContaining('Máx.'),
      find.text('31 oct'),
    ]) {
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('equal e1RM extrema retain safe bounds and disclose the range',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExerciseOneRmChart(
          data: [
            ExerciseProgressPoint(date: DateTime(2026, 10, 1), value: 39),
            ExerciseProgressPoint(date: DateTime(2026, 10, 31), value: 39),
          ],
          weightUnit: WeightUnit.kg,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final chart = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(chart.minY, lessThan(39));
    expect(chart.maxY, greaterThan(39));
    expect(find.text('Mín. 39 kg'), findsOneWidget);
    expect(find.text('Máx. 39 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
