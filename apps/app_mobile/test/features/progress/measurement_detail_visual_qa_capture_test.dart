import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/domain/models/body_measurement.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/body_measurement_silhouette.dart';

/// Synthetic fixtures for screenshot QA only. These are never user records.
final _older = BodyMeasurement(
  id: 'qa-older',
  date: DateTime(2026, 1, 5),
  neckCm: 37,
  shouldersCm: 112,
  chestCm: 110,
  leftArmCm: 32,
  rightArmCm: 33,
  leftForearmCm: 27,
  rightForearmCm: 28,
  waistCm: 82,
  hipsCm: 95,
  leftLegCm: 54,
  rightLegCm: 55,
  leftCalfCm: 35,
  rightCalfCm: 36,
);
final _newer = BodyMeasurement(
  id: 'qa-newer',
  date: DateTime(2026, 11, 14),
  neckCm: 38,
  shouldersCm: 114,
  chestCm: 118,
  leftArmCm: 34,
  rightArmCm: 35,
  leftForearmCm: 28,
  rightForearmCm: 29,
  waistCm: 82,
  hipsCm: 97,
  leftLegCm: 56,
  rightLegCm: 57,
  leftCalfCm: 36,
  rightCalfCm: 37,
);

void main() {
  for (final dark in [false, true]) {
    testWidgets('capture all 13 detail contours in ${dark ? 'dark' : 'light'}',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final folder = Directory('build/measurement_detail_qa')
        ..createSync(recursive: true);
      final metrics = SilhouetteMeasurementData.metrics;
      expect(metrics.length, 13);
      for (final metric in metrics) {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            fontFamily: 'Outfit',
            colorSchemeSeed: Colors.blue,
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          home: RepaintBoundary(
            key: const Key('detail_qa_capture'),
            child: MeasurementMuscleDetailPage(
              metric: metric,
              measurements: [_older, _newer],
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('measurement_detail_anatomy')),
            findsOneWidget, reason: metric.name);
        expect(find.byKey(const Key('measurement_detail_value')),
            findsOneWidget, reason: metric.name);
        expect(find.byKey(const Key('measurement_detail_chart')),
            findsOneWidget, reason: metric.name);
        expect(tester.takeException(), isNull, reason: metric.name);

        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('detail_qa_capture')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            expect(bytes, isNotNull);
            final file = File(
              '${folder.path}/${metric.name}_${dark ? 'dark' : 'light'}.png',
            );
            file.writeAsBytesSync(bytes!.buffer.asUint8List(
              bytes.offsetInBytes, bytes.lengthInBytes,
            ));
            expect(file.lengthSync(), greaterThan(5000));
          } finally {
            image.dispose();
          }
        });
      }
    });
  }
}
