import 'package:core/core/theme/app_palette.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/body_measurement_summary.dart';

final _past = BodyMeasurement(
  id: 'past', date: DateTime(2026, 8, 12),
  weightKg: 76, bodyFatPercentage: 17.5, heightCm: 177,
  waistCm: 80, hipsCm: 100,
);
final _latest = BodyMeasurement(
  id: 'new', date: DateTime(2026, 10, 28),
  weightKg: 74, bodyFatPercentage: 15.4, heightCm: 178,
  waistCm: 78, hipsCm: 104,
);
final _partial = BodyMeasurement(
  id: 'partial', date: DateTime(2026, 10, 29),
  waistCm: 75,
);

void main() {
  test('latest per metric from partial entries and earlier valid date', () {
    final records = [_past, _latest, _partial];
    expect(MeasurementSummaryData.weight(records)!.value, 74);
    expect(MeasurementSummaryData.weight(records)!.difference, -2);
    expect(MeasurementSummaryData.fat(records)!.value, 15.4);
    expect(MeasurementSummaryData.height(records)!.value, 178);
    expect(MeasurementSummaryData.height(records)!.difference, 1);
    final ratio = MeasurementSummaryData.waistHipRatio(records)!;
    expect(ratio.value, closeTo(78 / 104, 0.00001));
    expect(ratio.previous, closeTo(80 / 100, 0.00001));
    expect(ratio.date, DateTime(2026, 10, 28));
  });
  test('never joins unrelated dates for waist/hip', () {
    final records = [
      BodyMeasurement(id: 'w', date: DateTime(2026, 10, 30), waistCm: 80),
      BodyMeasurement(id: 'h', date: DateTime(2026, 10, 29), hipsCm: 105),
    ];
    expect(MeasurementSummaryData.waistHipRatio(records), isNull);
  });
  test('missing, zero, NaN height remain empty rather than 0', () {
    final records = [
      BodyMeasurement(id: 'a', date: DateTime(2026, 1)),
      BodyMeasurement(id: 'b', date: DateTime(2026, 2), heightCm: 0),
      BodyMeasurement(id: 'c', date: DateTime(2026, 3), heightCm: double.nan),
    ];
    expect(MeasurementSummaryData.height(records), isNull);
    expect(MeasurementSummaryData.height([]), isNull);
  });

  for (final dark in [false, true]) {
    for (final accent in AppAccent.values) {
      testWidgets('summary 4 tiles in ${dark ? "dark" : "light"} / ${accent.name}, 320px',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final themeMode = dark ? Brightness.dark : Brightness.light;
          final appearance = AppearanceSettings(accent: accent);
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(
              brightness: themeMode,
              extensions: [AppColors.from(appearance, themeMode)],
            ),
            home: Scaffold(body: SingleChildScrollView(
              child: BodyMeasurementSummary(
                measurements: [_past, _latest, _partial],
                weightUnit: WeightUnit.kg,
              ),
            )),
          ));
          await tester.pumpAndSettle();
          for (final key in ['summary_weight','summary_fat',
              'summary_waist_hip','summary_height']) {
            expect(find.byKey(Key(key)), findsOneWidget);
          }
          expect(find.text('74.0 kg'), findsOneWidget);
          expect(find.text('15.4 %'), findsOneWidget);
          expect(find.text('0.75'), findsOneWidget);
          expect(find.text('178.0 cm'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('summary respects lb and shows no made-up height', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: BodyMeasurementSummary(
        measurements: [
          BodyMeasurement(id:'weight',date:DateTime(2026,9),weightKg:85),
        ],
        weightUnit: WeightUnit.lb,
      )),
    )));
    await tester.pumpAndSettle();
    expect(find.text('187.4 lb'), findsOneWidget);
    expect(find.text('Agrégala en Nueva medida'), findsOneWidget);
    expect(find.text('Registra ambas juntas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
