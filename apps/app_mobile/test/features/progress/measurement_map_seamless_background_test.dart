import 'dart:io';

import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/progress/domain/measurement_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/body_measurement_silhouette.dart';

void main() {
  test('the map wrapper has no opaque rectangle on either view', () {
    final code = File(
      'lib/features/progress/presentation/widgets/body_measurement_silhouette.dart',
    ).readAsStringSync();

    expect(code, contains("Key(_back ? 'silhouette_back' : 'silhouette_front')"));
    expect(code, contains('KeyedSubtree('));
    // The anatomy image and cards must float on the surrounding page.
    expect(code, isNot(contains('color: accent.surface,')));
    // Do not remove the individual badge styles or anatomical coordinates.
    expect(code, contains('child: _MeasureCalloutBadge('));
    expect(code, contains('anchors:[for(final i in visible) anchors[i]]'));
    expect(code, contains("key: const Key('measurement_anatomy_png')"));
  });

  for (final variant in ['light', 'dark', 'oled']) {
    testWidgets('seamless front and back map in $variant theme',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final isDark = variant != 'light';
      final background = variant == 'oled'
          ? Colors.black
          : isDark
              ? const Color(0xff12131a)
              : const Color(0xfff7f8fb);
      final example = BodyMeasurement(
        id: 'seamless-map-qa',
        date: DateTime(2026, 11, 21),
        chestCm: 118,
        waistCm: 81,
        leftArmCm: 41,
        rightArmCm: 41,
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
          scaffoldBackgroundColor: background,
          colorSchemeSeed: Colors.blue,
        ),
        home: Scaffold(
          backgroundColor: background,
          body: SingleChildScrollView(
            child: BodyMeasurementSilhouette(
              measurements: [example],
              selected: MeasurementMetric.chest,
              onSelected: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        tester.widget(find.byKey(const Key('silhouette_front'))),
        isA<KeyedSubtree>(),
      );
      expect(find.byKey(const Key('measurement_anatomy_png')), findsOneWidget);
      expect(find.byKey(const Key('measure_chip_chest')), findsOneWidget);
      expect(find.byKey(const Key('map_front_chest')), findsOneWidget);

      await tester.ensureVisible(find.text('Espalda').last);
      await tester.tap(find.text('Espalda').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget(find.byKey(const Key('silhouette_back'))),
        isA<KeyedSubtree>(),
      );
      expect(find.byKey(const Key('measurement_anatomy_png')), findsOneWidget);
      expect(find.byKey(const Key('map_back_waist')), findsOneWidget);
      expect(find.byKey(const Key('silhouette_front')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
