import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/progress/domain/measurement_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/body_measurement_silhouette.dart';

void main() {
  test('measurement points are chronological, latest always last', () {
    final now = DateTime(2026, 11, 14);
    final history = MeasurementProgress([
      BodyMeasurement(id: 'latest', date: now, chestCm: 118),
      BodyMeasurement(id: 'old', date: now.subtract(const Duration(days: 14)), chestCm: 110),
    ], MeasurementMetric.chest);
    expect(history.points.map((p) => p.value).toList(), [110, 118]);
  });

  testWidgets('detail separates prior value and delta without positive health judgement',
      (tester) async {
    final now = DateTime(2026, 11, 14);
    await tester.pumpWidget(MaterialApp(
      home: MeasurementMuscleDetailPage(
        metric: MeasurementMetric.chest,
        measurements: [
          BodyMeasurement(id: 'old', date: now.subtract(const Duration(days: 14)), chestCm: 110),
          BodyMeasurement(id: 'new', date: now, chestCm: 118),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Medida anterior'), findsOneWidget);
    expect(find.text('110.0 cm'), findsOneWidget);
    expect(find.text('+8.0 cm'), findsWidgets);
    expect(find.byKey(const Key('measurement_detail_chart')), findsOneWidget);
    expect(find.byKey(const Key('measurement_chart_selected_record')), findsOneWidget);
    expect(find.text('Registros recientes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unchanged waist is neutral and chronological chart still visible',
      (tester) async {
    final now = DateTime(2026, 11, 14);
    await tester.pumpWidget(MaterialApp(
      home: MeasurementMuscleDetailPage(
        metric: MeasurementMetric.waist,
        measurements: [
          BodyMeasurement(id: 'old', date: now.subtract(const Duration(days: 14)), waistCm: 82),
          BodyMeasurement(id: 'new', date: now, waistCm: 82),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sin cambio'), findsWidgets);
    expect(find.byKey(const Key('measurement_detail_chart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
