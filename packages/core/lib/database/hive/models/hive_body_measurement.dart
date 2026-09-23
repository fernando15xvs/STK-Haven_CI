import 'package:hive/hive.dart';
import '../../../domain/models/body_measurement.dart';

part 'hive_body_measurement.g.dart';

@HiveType(typeId: 11)
class HiveBodyMeasurement extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final double? weightKg;

  @HiveField(3)
  final double? bodyFatPercentage;

  @HiveField(4)
  final double? chestCm;

  @HiveField(5)
  final double? waistCm;

  @HiveField(6)
  final double? leftArmCm;

  @HiveField(7)
  final double? rightArmCm;

  @HiveField(8)
  final double? leftLegCm;

  @HiveField(9)
  final double? rightLegCm;

  @HiveField(10)
  final double? calvesCm;

  @HiveField(11)
  final double? shouldersCm;

  @HiveField(12)
  final double? hipsCm;

  HiveBodyMeasurement({
    required this.id,
    required this.date,
    this.weightKg,
    this.bodyFatPercentage,
    this.shouldersCm,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.leftArmCm,
    this.rightArmCm,
    this.leftLegCm,
    this.rightLegCm,
    this.calvesCm,
  });

  factory HiveBodyMeasurement.fromDomain(BodyMeasurement m) {
    return HiveBodyMeasurement(
      id: m.id,
      date: m.date,
      weightKg: m.weightKg,
      bodyFatPercentage: m.bodyFatPercentage,
      shouldersCm: m.shouldersCm,
      chestCm: m.chestCm,
      waistCm: m.waistCm,
      hipsCm: m.hipsCm,
      leftArmCm: m.leftArmCm,
      rightArmCm: m.rightArmCm,
      leftLegCm: m.leftLegCm,
      rightLegCm: m.rightLegCm,
      calvesCm: m.calvesCm,
    );
  }

  BodyMeasurement toDomain() {
    return BodyMeasurement(
      id: id,
      date: date,
      weightKg: weightKg,
      bodyFatPercentage: bodyFatPercentage,
      shouldersCm: shouldersCm,
      chestCm: chestCm,
      waistCm: waistCm,
      hipsCm: hipsCm,
      leftArmCm: leftArmCm,
      rightArmCm: rightArmCm,
      leftLegCm: leftLegCm,
      rightLegCm: rightLegCm,
      calvesCm: calvesCm,
    );
  }
}
