import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/progress/domain/measurement_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/body_measurement_silhouette.dart';

final _complete = BodyMeasurement(
  id: 'all-contours',
  date: DateTime(2026, 11, 14),
  neckCm: 38,
  shouldersCm: 120,
  chestCm: 105,
  leftArmCm: 35,
  rightArmCm: 36,
  leftForearmCm: 29,
  rightForearmCm: 30,
  waistCm: 82,
  hipsCm: 96,
  leftLegCm: 57,
  rightLegCm: 58,
  leftCalfCm: 36,
  rightCalfCm: 37,
);

const _front = [
  MeasurementMetric.neck,
  MeasurementMetric.shoulders,
  MeasurementMetric.chest,
  MeasurementMetric.leftArm,
  MeasurementMetric.rightArm,
  MeasurementMetric.leftLeg,
  MeasurementMetric.rightLeg,
];
const _rear = [
  MeasurementMetric.leftForearm,
  MeasurementMetric.rightForearm,
  MeasurementMetric.waist,
  MeasurementMetric.hips,
  MeasurementMetric.leftCalf,
  MeasurementMetric.rightCalf,
];

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('all recorded badges remain distinct at ${width.toInt()}dp x$scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(fontFamily: 'Outfit'),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(body: SingleChildScrollView(
              child: BodyMeasurementSilhouette(
                measurements: [_complete],
                selected: MeasurementMetric.chest,
                onSelected: (_) {},
              ),
            )),
          ),
        ));
        await tester.pumpAndSettle();

        void assertBadges(List<MeasurementMetric> metrics) {
          final rectangles = <Rect>[];
          for (final metric in metrics) {
            final finder = find.byKey(Key('measure_chip_${metric.name}'));
            expect(finder, findsOneWidget);
            rectangles.add(tester.getRect(finder));
          }
          for (var a = 0; a < rectangles.length; a++) {
            expect(rectangles[a].left, greaterThanOrEqualTo(0));
            expect(rectangles[a].right, lessThanOrEqualTo(width));
            for (var b = a + 1; b < rectangles.length; b++) {
              expect(rectangles[a].overlaps(rectangles[b]), isFalse,
                reason: 'Badge ${metrics[a]} must not cover ${metrics[b]}');
            }
          }
        }

        assertBadges(_front);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Espalda').last);
        await tester.tap(find.text('Espalda').last);
        await tester.pumpAndSettle();
        assertBadges(_rear);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
