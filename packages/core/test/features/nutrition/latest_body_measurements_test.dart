import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/nutrition/application/latest_body_measurements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('independent latest weight and height survive partial recent entries', () {
    final latest = LatestBodyMeasurements.fromRecords([
      BodyMeasurement(
        id: 'waist-only',
        date: DateTime(2026, 11, 14),
        waistCm: 83,
      ),
      BodyMeasurement(
        id: 'height',
        date: DateTime(2026, 11, 1),
        heightCm: 175,
      ),
      BodyMeasurement(
        id: 'weight',
        date: DateTime(2026, 11, 10),
        weightKg: 75,
      ),
    ]);
    expect(latest.canEstimateEnergy, isTrue);
    expect(latest.weightKg?.value, 75);
    expect(latest.weightKg?.recordId, 'weight');
    expect(latest.weightKg?.recordedAt.day, 10);
    expect(latest.heightCm?.value, 175);
    expect(latest.heightCm?.recordId, 'height');
    expect(latest.heightCm?.recordedAt.day, 1);
  });

  test('no default body statistics for empty history', () {
    const empty = <BodyMeasurement>[];
    final latest = LatestBodyMeasurements.fromRecords(empty);
    expect(latest.weightKg, isNull);
    expect(latest.heightCm, isNull);
    expect(latest.canEstimateEnergy, isFalse);
  });

  test('skips unusable recent values without altering source history', () {
    final records = [
      BodyMeasurement(id: 'bad', date: DateTime(2026, 11, 12),
        weightKg: double.nan, heightCm: 0),
      BodyMeasurement(id: 'legacy', date: DateTime(2026, 11, 1),
        weightKg: 78, heightCm: 180),
    ];
    final data = LatestBodyMeasurements.fromRecords(records);
    expect(data.weightKg?.value, 78);
    expect(data.heightCm?.value, 180);
    expect(records.first.id, 'bad');
  });

  test('latest valid body-fat percent has its own dated source', () {
    final latest=LatestBodyMeasurements.fromRecords([
      BodyMeasurement(id:'recent-w',date:DateTime(2026,11,15),
        weightKg:72, bodyFatPercentage:double.nan),
      BodyMeasurement(id:'fat',date:DateTime(2026,11,12),
        bodyFatPercentage:21.5),
      BodyMeasurement(id:'height',date:DateTime(2026,11,1),
        heightCm:177),
    ]);
    expect(latest.bodyFatPercentage?.value,21.5);
    expect(latest.bodyFatPercentage?.recordId,'fat');
    expect(latest.weightKg?.recordId,'recent-w');
    expect(latest.heightCm?.recordId,'height');
    expect(latest.canEstimateEnergy,isTrue);
  });

  test('body-fat alone does not satisfy energy equation requirements', () {
    final latest=LatestBodyMeasurements.fromRecords([
      BodyMeasurement(id:'fat',date:DateTime(2026,11,15),
        bodyFatPercentage:20),
    ]);
    expect(latest.bodyFatPercentage?.value,20);
    expect(latest.canEstimateEnergy,isFalse);
  });
}
