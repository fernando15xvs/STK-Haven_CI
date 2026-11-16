import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/nutrition/application/nutrition_weight_trend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BodyMeasurement entry(String id, int day, {double? kg, double? waist}) =>
      BodyMeasurement(
        id:id,date:DateTime(2026,11,day,10),
        weightKg:kg,waistCm:waist,
      );

  test('two actual dated weights are compared, never a waist-only entry', () {
    final trend=NutritionWeightTrend.fromRecords([
      entry('waist',15,waist:77),
      entry('old',10,kg:72),
      entry('new',14,kg:70.8),
    ]);
    expect(trend,isNotNull);
    expect(trend!.previousRecordId,'old');
    expect(trend.latestRecordId,'new');
    expect(trend.differenceKg,closeTo(-1.2,0.00001));
    expect(trend.latestDate.day,14);
  });

  test('same-day edits do not create a fake trend', () {
    final trend=NutritionWeightTrend.fromRecords([
      BodyMeasurement(id:'morning',date:DateTime(2026,11,14,7),weightKg:74),
      BodyMeasurement(id:'evening',date:DateTime(2026,11,14,19),weightKg:75),
    ]);
    expect(trend,isNull);
  });

  test('invalid, absent or only one measurement has no trend', () {
    final actual=entry('actual',12,kg:68);
    expect(NutritionWeightTrend.fromRecords([actual]),isNull);
    expect(NutritionWeightTrend.fromRecords([
      actual,entry('invalid',13,kg:double.nan),
      entry('infinite',14,kg:double.infinity),
      entry('only-waist',15,waist:75),
    ]),isNull);
  });

  test('latest valid record per calendar day is used', () {
    final trend=NutritionWeightTrend.fromRecords([
      entry('old',8,kg:80),
      BodyMeasurement(id:'first-today',date:DateTime(2026,11,12,6),weightKg:79),
      BodyMeasurement(id:'last-today',date:DateTime(2026,11,12,18),weightKg:78),
    ]);
    expect(trend?.latestRecordId,'last-today');
    expect(trend?.previousRecordId,'old');
    expect(trend?.differenceKg,-2);
  });
}
