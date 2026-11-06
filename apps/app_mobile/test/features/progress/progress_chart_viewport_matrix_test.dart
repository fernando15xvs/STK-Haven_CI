import 'package:core/core/theme/app_palette.dart';
import 'package:core/core/utils/weight_converter.dart';
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

  final volume = <VolumeDataPoint>[
    VolumeDataPoint(DateTime(2026, 10, 6), 2800),
    VolumeDataPoint(DateTime(2026, 10, 10), 15912),
    VolumeDataPoint(DateTime(2026, 10, 31), 3000),
  ];
  final strength = <ExerciseProgressPoint>[
    ExerciseProgressPoint(date: DateTime(2026, 9, 2), value: 24),
    ExerciseProgressPoint(date: DateTime(2026, 10, 15), value: 39),
    ExerciseProgressPoint(date: DateTime(2026, 10, 31), value: 37.7),
  ];

  testWidgets('actual 1RM chart uses the selected unit for spots and bounds',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final unit in [WeightUnit.kg, WeightUnit.lb]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ExerciseOneRmChart(data: strength, weightUnit: unit),
        ),
      ));
      await tester.pumpAndSettle();
      final plot = tester.widget<LineChart>(find.byType(LineChart)).data;
      final spots = plot.lineBarsData.single.spots;
      final expected = WeightConverter.displayWeight(39, unit);
      expect(spots[1].y, closeTo(expected, 0.001));
      expect(plot.maxY, greaterThan(expected));
      expect(plot.minY, lessThan(spots.first.y));
      expect(find.text('2 sept'), findsOneWidget);
      expect(find.text('31 oct'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('same-day 1RM observations display only the last valid set',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExerciseOneRmChart(
          data: [
            ExerciseProgressPoint(date: DateTime(2026, 10, 6, 10), value: 35),
            ExerciseProgressPoint(date: DateTime(2026, 10, 6, 18), value: 39),
            ExerciseProgressPoint(date: DateTime(2026, 10, 31, 18), value: 37.7),
          ],
          weightUnit: WeightUnit.kg,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final chart = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(chart.lineBarsData.single.spots.length, 2);
    expect(chart.lineBarsData.single.spots.first.y, 39);
    expect(chart.maxY, greaterThan(39));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExerciseOneRmChart(
          data: [
            ExerciseProgressPoint(date: DateTime(2026, 10, 6, 10), value: 35),
            ExerciseProgressPoint(date: DateTime(2026, 10, 6, 18), value: 39),
          ],
          weightUnit: WeightUnit.kg,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsNothing);
    expect(find.textContaining('al menos 2 entrenamientos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Reproduce the screenshot edge/clipping cases without private user data.
  // Test both charts at narrow/wide layouts and scaled font sizes.
  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    for (final textScale in [1.0, 1.3, 1.6]) {
      for (final brightness in [Brightness.dark, Brightness.light]) {
        testWidgets(
          'chart edges ${width.toInt()}px text=$textScale '
          '${brightness.name} (OLED included)',
          (tester) async {
            tester.view.physicalSize = Size(width, 880);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            for (final oled in brightness == Brightness.dark
                ? <bool>[false, true]
                : <bool>[false]) {
              final colors = AppColors.from(
                AppearanceSettings(
                  accent: AppAccent.emerald,
                  oledBlack: oled,
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
                      size: Size(width, 880),
                      textScaler: TextScaler.linear(textScale),
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

              expect(find.byType(LineChart), findsNWidgets(2));
              final charts =
                  tester.widgetList<LineChart>(find.byType(LineChart)).toList();
              expect(find.text('6 oct'), findsOneWidget);
              expect(find.text('31 oct'), findsNWidgets(2));
              expect(find.text('2 sept'), findsOneWidget);
              for (final finder in [
                find.text('6 oct'),
                find.text('31 oct').first,
                find.text('31 oct').last,
                find.text('2 sept'),
              ]) {
                final rect = tester.getRect(finder);
                expect(rect.left, greaterThanOrEqualTo(0));
                expect(rect.right, lessThanOrEqualTo(width));
              }
              for (final chart in charts) {
                final plot = chart.data;
                final spots = plot.lineBarsData.first.spots;
                expect(plot.maxX, greaterThan(spots.last.x));
                expect(plot.minX, lessThan(spots.first.x));
                expect(plot.maxY, greaterThan(
                  spots.map((p) => p.y).reduce(
                    (a, b) => a > b ? a : b,
                  ),
                ));
                final tooltip = plot.lineTouchData.touchTooltipData;
                expect(tooltip.fitInsideHorizontally, isTrue);
                expect(tooltip.fitInsideVertically, isTrue);
              }
              final context = tester.element(find.byType(VolumeChart));
              expect(AppColors.contrast(
                ProgressChartStyle.tooltipText(context).color!,
                ProgressChartStyle.tooltipBackground(context),
              ), greaterThanOrEqualTo(4.5));
              expect(AppColors.contrast(
                ProgressChartStyle.axisText(context).color!,
                colors.surface,
              ), greaterThanOrEqualTo(4.5));
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  }
  testWidgets('DES-07: both charts honor OS Reduce Motion', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                VolumeChart(data: volume, weightUnit: WeightUnit.kg),
                ExerciseOneRmChart(data: strength, weightUnit: WeightUnit.kg),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final charts = tester.widgetList<LineChart>(find.byType(LineChart)).toList();
    expect(charts, hasLength(2));
    for (final chart in charts) {
      expect(chart.duration, Duration.zero,
          reason: 'System Reduce Motion disables animated chart transitions');
    }
    expect(tester.takeException(), isNull);
  });

}
