import 'package:core/core/theme/app_palette.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/progress_chart_style.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/volume_chart.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('es'));

  final unevenDates = [
    VolumeDataPoint(DateTime(2026, 10, 6), 3000),
    VolumeDataPoint(DateTime(2026, 10, 10), 15912),
    VolumeDataPoint(DateTime(2026, 10, 31), 2500),
  ];

  test('shared formatting includes readable group separators and units', () {
    expect(ProgressChartStyle.number(15912), '15.912');
    expect(ProgressChartStyle.measurement(15912, WeightUnit.kg), '15.912 kg');
    expect(ProgressChartStyle.detailedDate(DateTime(2026, 10, 31)),
        '31 oct 2026');
  });

  test('chart bounds are based on display units and support flat curves', () {
    final kgValues = [25.0, 37.7, 39.0];
    final lbValues = [
      for (final value in kgValues)
        WeightConverter.displayWeight(value, WeightUnit.lb),
    ];
    final kg = ProgressChartStyle.bounds(kgValues);
    final lb = ProgressChartStyle.bounds(lbValues);
    expect(kg.minY, lessThan(kgValues.first));
    expect(kg.maxY, greaterThan(kgValues.last));
    expect(lb.minY, lessThan(lbValues.first));
    expect(lb.maxY, greaterThan(lbValues.last));
    final positionKg =
        (kgValues[1] - kg.minY) / (kg.maxY - kg.minY);
    final positionLb =
        (lbValues[1] - lb.minY) / (lb.maxY - lb.minY);
    expect(positionLb, closeTo(positionKg, 0.001));
    final flat = ProgressChartStyle.bounds([37.7, 37.7]);
    expect(flat.minY, lessThan(37.7));
    expect(flat.maxY, greaterThan(37.7));
  });

  for (final brightness in [Brightness.dark, Brightness.light]) {
    for (final accent in AppAccent.values) {
      testWidgets(
        'volume chart 320 px ${brightness.name}/${accent.name} has readable labels',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final colors = AppColors.from(
            AppearanceSettings(accent: accent),
            brightness,
          );
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(brightness: brightness, extensions: [colors]),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: VolumeChart(
                  data: unevenDates,
                  weightUnit: WeightUnit.kg,
                ),
              ),
            ),
          ));
          await tester.pumpAndSettle();

          expect(find.text('6 oct'), findsOneWidget);
          expect(find.text('31 oct'), findsOneWidget);
          final chart = tester.widget<LineChart>(find.byType(LineChart));
          expect(chart.data.lineBarsData.single.spots[1].x, closeTo(4, 0.001));
          expect(chart.data.lineBarsData.single.spots.last.x,
              closeTo(25, 0.001));
          expect(
            AppColors.contrast(
              ProgressChartStyle.tooltipText(
                tester.element(find.byType(VolumeChart)),
              ).color!,
              ProgressChartStyle.tooltipBackground(
                tester.element(find.byType(VolumeChart)),
              ),
            ),
            greaterThanOrEqualTo(4.5),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('3M weekly buckets disclose the aggregation at narrow width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final values = bucketVolumeChartData([
      VolumeDataPoint(DateTime(2026, 8, 5), 100),
      VolumeDataPoint(DateTime(2026, 8, 6), 200),
      VolumeDataPoint(DateTime(2026, 8, 12), 450),
    ], filter: TimeFilter.threeMonths,
       startDate: DateTime(2026, 8, 5));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VolumeChart(
          data: values,
          weightUnit: WeightUnit.kg,
          period: TimeFilter.threeMonths,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sem. 5 ago'), findsOneWidget);
    expect(find.text('Sem. 12 ago'), findsOneWidget);
    final plot = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(plot.lineBarsData.single.spots.map((s) => s.y), [300, 450]);
    expect(plot.lineTouchData.touchTooltipData.fitInsideHorizontally, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1A calendar month labels retain months despite empty weeks',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final values = bucketVolumeChartData([
      VolumeDataPoint(DateTime(2026, 1, 9), 15912),
      VolumeDataPoint(DateTime(2026, 4, 7), 2500),
    ], filter: TimeFilter.year,
       startDate: DateTime(2025, 11, 3));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: VolumeChart(
            data: values,
            weightUnit: WeightUnit.kg,
            period: TimeFilter.year,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ene 2026'), findsOneWidget);
    expect(find.text('abr 2026'), findsOneWidget);
    final spots =
        tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.single.spots;
    expect(spots[1].x, greaterThan(80));
    expect(spots[0].y, 15912);
    expect(tester.takeException(), isNull);
  });

  testWidgets('volume chart sums duplicate dates and skips invalid imports',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VolumeChart(
          data: [
            VolumeDataPoint(DateTime(2026, 10, 6, 12), 120),
            VolumeDataPoint(DateTime(2026, 10, 6, 18), 80),
            VolumeDataPoint(DateTime(2026, 10, 7), double.nan),
            VolumeDataPoint(DateTime(2026, 10, 9), 15912),
          ],
          weightUnit: WeightUnit.kg,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final spots =
        tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.single.spots;
    expect(spots.length, 2);
    expect(spots.map((spot) => spot.y), [200, 15912]);
    expect(spots.last.x, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one point, zero volume, and enlarged text do not overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: VolumeChart(
            data: [VolumeDataPoint(DateTime(2026, 10, 31), 0)],
            weightUnit: WeightUnit.lb,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('31 oct'), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minY, 0);
    expect(chart.data.maxY, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
