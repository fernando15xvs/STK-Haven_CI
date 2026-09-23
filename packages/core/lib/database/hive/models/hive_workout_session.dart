import 'package:hive/hive.dart';

part 'hive_workout_session.g.dart';

@HiveType(typeId: 5)
class HiveWorkoutSet {
  @HiveField(0)
  double weight;
  @HiveField(1)
  int reps;
  @HiveField(2)
  bool completed;
  @HiveField(3)
  int? rir; // nullable: null = not recorded, 0 = failure
  @HiveField(4)
  bool warmup; // legacy + compatibilidad con backups antiguos
  @HiveField(5)
  int restSeconds;
  @HiveField(6)
  String setType;
  @HiveField(7)
  bool leftCompleted;
  @HiveField(8)
  bool rightCompleted;
  @HiveField(9)
  double? leftWeight;
  @HiveField(10)
  int? leftReps;
  @HiveField(11)
  int? leftRir;
  @HiveField(12)
  double? rightWeight;
  @HiveField(13)
  int? rightReps;
  @HiveField(14)
  int? rightRir;
  @HiveField(15)
  int sideRestSeconds;

  HiveWorkoutSet({
    required this.weight,
    required this.reps,
    required this.completed,
    this.rir,
    this.warmup = false,
    this.restSeconds = 0,
    this.setType = 'working',
    this.leftCompleted = false,
    this.rightCompleted = false,
    this.leftWeight,
    this.leftReps,
    this.leftRir,
    this.rightWeight,
    this.rightReps,
    this.rightRir,
    this.sideRestSeconds = 60,
  });
}

@HiveType(typeId: 6)
class HiveWorkoutExercise {
  @HiveField(0)
  String exerciseId;
  @HiveField(1)
  List<HiveWorkoutSet> sets;
  @HiveField(2)
  String notes;
  @HiveField(3)
  String exerciseNameSnapshot;
  @HiveField(4)
  String muscleGroupSnapshot;
  @HiveField(5)
  bool unilateral;
  @HiveField(6)
  String unilateralTarget;
  @HiveField(7)
  String? supersetGroupId;

  HiveWorkoutExercise({
    required this.exerciseId,
    required this.sets,
    this.notes = '',
    this.exerciseNameSnapshot = '',
    this.muscleGroupSnapshot = '',
    this.unilateral = false,
    this.unilateralTarget = 'other',
    this.supersetGroupId,
  });
}

@HiveType(typeId: 7)
class HiveWorkoutSession extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String? routineId;
  @HiveField(2)
  DateTime startedAt;
  @HiveField(3)
  DateTime finishedAt;
  @HiveField(4)
  List<HiveWorkoutExercise> exercises;
  @HiveField(5)
  int durationSeconds;
  @HiveField(6)
  String notes;
  @HiveField(7)
  String routineNameSnapshot;
  @HiveField(8)
  DateTime? currentRestEndsAt;

  HiveWorkoutSession({
    required this.id,
    this.routineId,
    required this.startedAt,
    required this.finishedAt,
    required this.exercises,
    required this.durationSeconds,
    this.notes = '',
    this.routineNameSnapshot = '',
    this.currentRestEndsAt,
  });
}