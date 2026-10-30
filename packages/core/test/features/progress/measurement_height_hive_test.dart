import 'package:core/database/hive/models/hive_body_measurement.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('height is optional for all existing historical Hive measurements', () {
    final historic = HiveBodyMeasurement(
      id: 'legacy', date: DateTime(2025, 9, 20),
      weightKg: 84, waistCm: 83,
    );
    final domain = historic.toDomain();
    expect(domain.heightCm, isNull);
    expect(domain.weightKg, 84);
    expect(domain.waistCm, 83);
  });

  test('new height is retained through Hive domain mapping and copyWith', () {
    final original = BodyMeasurement(
      id: 'new', date: DateTime(2026, 10, 30),
      heightCm: 176.5, weightKg: 78, chestCm: 103,
    );
    final stored = HiveBodyMeasurement.fromDomain(original);
    expect(stored.heightCm, 176.5);
    final restored = stored.toDomain();
    expect(restored.heightCm, 176.5);
    expect(restored.copyWith(heightCm: 178).heightCm, 178);
    expect(restored.chestCm, 103);
  });

  test('new tape fields round-trip and legacy calves stay unsided', () {
    final legacy=HiveBodyMeasurement(id:'old',date:DateTime(2025),calvesCm:38).toDomain();
    expect(legacy.calvesCm,38);
    expect(legacy.leftCalfCm,isNull);
    expect(legacy.rightCalfCm,isNull);
    final fresh=BodyMeasurement(id:'new',date:DateTime(2026),
      neckCm:38.5,leftForearmCm:30,rightForearmCm:31,
      leftCalfCm:36,rightCalfCm:37);
    final restored=HiveBodyMeasurement.fromDomain(fresh).toDomain();
    expect(restored.neckCm,38.5);
    expect(restored.leftForearmCm,30);
    expect(restored.rightForearmCm,31);
    expect(restored.leftCalfCm,36);
    expect(restored.rightCalfCm,37);
  });

  test('height remains absent when only other circumferences are recorded', () {
    final restored = HiveBodyMeasurement.fromDomain(BodyMeasurement(
      id:'partial', date:DateTime(2026,10,30), leftArmCm:33,
    )).toDomain();
    expect(restored.heightCm, isNull);
    expect(restored.leftArmCm, 33);
  });
}
