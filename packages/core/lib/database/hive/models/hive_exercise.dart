import 'package:hive/hive.dart';

part 'hive_exercise.g.dart';

@HiveType(typeId: 8)
class HiveExercise extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String muscleGroup;
  @HiveField(3)
  List<String> secondaryMuscles;
  @HiveField(4)
  String equipment;
  @HiveField(5)
  String instructions;
  @HiveField(6)
  String media;

  HiveExercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.secondaryMuscles = const [],
    this.equipment = '',
    this.instructions = '',
    this.media = '',
  });
}
