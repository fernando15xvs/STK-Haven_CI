import 'package:hive/hive.dart';

part 'hive_routine.g.dart';

@HiveType(typeId: 3)
class HiveRoutineExercise {
  @HiveField(0)
  String exerciseId;
  @HiveField(1)
  int order;
  @HiveField(2)
  int targetSets;
  @HiveField(3)
  int targetRepsMin;
  @HiveField(4)
  int targetRepsMax;
  @HiveField(5)
  int restSeconds;
  @HiveField(6)
  int warmupSets;
  @HiveField(7)
  int approachSets;
  @HiveField(8)
  bool unilateral;
  @HiveField(9)
  String unilateralTarget;
  @HiveField(10)
  String? supersetGroupId;

  HiveRoutineExercise({
    required this.exerciseId,
    required this.order,
    required this.targetSets,
    required this.targetRepsMin,
    required this.targetRepsMax,
    required this.restSeconds,
    this.warmupSets = 0,
    this.approachSets = 0,
    this.unilateral = false,
    this.unilateralTarget = 'other',
    this.supersetGroupId,
  });
}

@HiveType(typeId: 4)
class HiveRoutine extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  List<int> scheduledDays;
  @HiveField(3)
  List<HiveRoutineExercise> exercises;
  @HiveField(4)
  DateTime createdAt;
  @HiveField(5)
  String notes;

  HiveRoutine({
    required this.id,
    required this.name,
    required this.scheduledDays,
    required this.exercises,
    required this.createdAt,
    this.notes = '',
  });
}
