import 'package:hive/hive.dart';

part 'hive_personal_record.g.dart';

@HiveType(typeId: 9)
enum HivePRType {
  @HiveField(0) maxWeight,
  @HiveField(1) estimated1RM,
  @HiveField(2) bestSetVolume,
}

@HiveType(typeId: 10)
class HivePersonalRecord extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String workoutSessionId;
  @HiveField(2)
  String exerciseId;
  @HiveField(3)
  String exerciseNameSnapshot;
  @HiveField(4)
  HivePRType type;
  @HiveField(5)
  double previousValue;
  @HiveField(6)
  double newValue;
  @HiveField(7)
  DateTime achievedAt;

  HivePersonalRecord({
    required this.id,
    required this.workoutSessionId,
    required this.exerciseId,
    required this.exerciseNameSnapshot,
    required this.type,
    required this.previousValue,
    required this.newValue,
    required this.achievedAt,
  });
}
