import 'package:flutter_test/flutter_test.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/progress/domain/measurement_progress.dart';
import 'package:core/features/progress/services/measurement_reminder_service.dart';

void main() {
  test(
    'calendar cadence handles leap years, short months and year boundary',
    () {
      expect(
        nextMeasurementDate(DateTime(2028, 1, 31), 1),
        DateTime(2028, 2, 29, 9),
      );
      expect(
        nextMeasurementDate(DateTime(2027, 1, 31), 1),
        DateTime(2027, 2, 28, 9),
      );
      expect(
        nextMeasurementDate(DateTime(2026, 11, 30), 3, hour: 18, minute: 30),
        DateTime(2027, 2, 28, 18, 30),
      );
      expect(
        nextMeasurementDate(DateTime(2026, 1, 31), 2),
        DateTime(2026, 3, 31, 9),
      );
      expect(() => nextMeasurementDate(DateTime(2026), 0), throwsArgumentError);
    },
  );
  test('latest measurement anchors reminder independent of list order', () {
    final list = [
      BodyMeasurement(id: 'a', date: DateTime(2026, 1, 31)),
      BodyMeasurement(id: 'b', date: DateTime(2026, 3, 15)),
    ];
    expect(
      const MeasurementReminderSettings(months: 2).dueDate(list),
      DateTime(2026, 5, 15, 9),
    );
    expect(const MeasurementReminderSettings().dueDate([]), isNull);
  });
  test(
    'metric comparisons ignore missing and invalid values, never turn them into zero',
    () {
      final progress = MeasurementProgress([
        BodyMeasurement(id: '3', date: DateTime(2026, 3), leftArmCm: 33),
        BodyMeasurement(id: '1', date: DateTime(2026, 1), leftArmCm: 30),
        BodyMeasurement(id: '2', date: DateTime(2026, 2), weightKg: 70),
        BodyMeasurement(
          id: '4',
          date: DateTime(2026, 4),
          leftArmCm: double.nan,
        ),
      ], MeasurementMetric.leftArm);
      expect(progress.points.length, 2);
      expect(progress.change, 3);
      expect(progress.changePercent, 10);
    },
  );
  test(
    'no comparison with one reading or identical timestamps; negative change supported',
    () {
      final one = BodyMeasurement(
        id: '1',
        date: DateTime(2026, 1),
        waistCm: 90,
      );
      expect(
        MeasurementProgress([one], MeasurementMetric.waist).change,
        isNull,
      );
      expect(
        MeasurementProgress([one, one], MeasurementMetric.waist).canCompare,
        false,
      );
      final two = BodyMeasurement(
        id: '2',
        date: DateTime(2026, 2),
        waistCm: 85,
      );
      expect(
        MeasurementProgress([two, one], MeasurementMetric.waist).change,
        -5,
      );
    },
  );
}
