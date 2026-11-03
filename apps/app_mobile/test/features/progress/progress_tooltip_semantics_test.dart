import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
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
  final rm = <ExerciseProgressPoint>[
    ExerciseProgressPoint(date: DateTime(2026, 9, 2), value: 24),
    ExerciseProgressPoint(date: DateTime(2026, 10, 15), value: 39),
    ExerciseProgressPoint(date: DateTime(2026, 10, 31), value: 37.7),
  ];

  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final unit in [WeightUnit.kg, WeightUnit.lb]) {
      testWidgets('tooltips return date and units, in ${brightness.name}/${unit.name}',
          (tester) async {
        tester.view.physicalSize = const Size(320, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final appearance = AppearanceSettings(
          oledBlack: brightness == Brightness.dark,
        );
        final colors = AppColors.from(appearance, brightness);
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness, extensions: [colors]),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.6),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    VolumeChart(data: volume, weightUnit: unit),
                    ExerciseOneRmChart(data: rm, weightUnit: unit),
                  ],
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final chartWidgets =
            tester.widgetList<LineChart>(find.byType(LineChart)).toList();
        expect(chartWidgets, hasLength(2));

        for (final chart in chartWidgets) {
          final line = chart.data.lineBarsData.single;
          final touched = LineBarSpot(line, 0, line.spots[1]);
          final tooltipData = chart.data.lineTouchData.touchTooltipData;
          final items = tooltipData.getTooltipItems([touched]);
          expect(items, hasLength(1));
          final tooltip = items.single;
          expect(tooltip.text, contains('2026'));
          expect(tooltip.text, contains(unit.label));
          expect(tooltip.text, isNot(contains('15912.0')));
          expect(tooltip.textStyle.fontFamily, 'Outfit');
          expect(tooltipData.fitInsideHorizontally, isTrue);
          expect(tooltipData.fitInsideVertically, isTrue);
          expect(tooltipData.maxContentWidth,
              ProgressChartStyle.tooltipMaxContentWidth);
          expect(tooltipData.tooltipPadding, ProgressChartStyle.tooltipPadding);
        }

        final volumeChart = chartWidgets.first.data.lineBarsData.single;
        final v = chartWidgets.first.data.lineTouchData.touchTooltipData
            .getTooltipItems([LineBarSpot(volumeChart, 0, volumeChart.spots[1])]);
        final weight = WeightConverter.displayWeight(15912, unit);
        expect(v.single.text, contains('10 oct 2026'));
        expect(v.single.text, contains(ProgressChartStyle.measurement(weight, unit)));

        final rmChart = chartWidgets.last.data.lineBarsData.single;
        final e = chartWidgets.last.data.lineTouchData.touchTooltipData
            .getTooltipItems([LineBarSpot(rmChart, 0, rmChart.spots[1])]);
        expect(e.single.text, contains('15 oct 2026'));
        expect(e.single.text, contains(
          ProgressChartStyle.measurement(
            WeightConverter.displayWeight(39, unit),
            unit,
          ),
        ));

        final context = tester.element(find.byType(VolumeChart));
        expect(
          AppColors.contrast(
            ProgressChartStyle.tooltipText(context).color!,
            ProgressChartStyle.tooltipBackground(context),
          ),
          greaterThanOrEqualTo(4.5),
        );

        final labels = tester.widgetList<Semantics>(
          find.byType(Semantics),
        ).map((s) => s.properties.label ?? '').toList(growable: false);
        expect(labels.any((label) =>
          label.contains('Máximo mostrado:') &&
          label.contains(ProgressChartStyle.measurement(weight, unit))),
          isTrue,
        );
        expect(labels.any((label) =>
          label.contains('Última estimación:') &&
          label.contains('Máximo mostrado:')),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
