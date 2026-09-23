import 'package:core/domain/models/preset_program.dart';

class RoutineTemplate {
  final String id;
  final String name;
  final String sourceProgramName;
  final String description;
  final String level;
  final List<int> suggestedDays;
  final List<PresetRoutineExercise> exercises;

  const RoutineTemplate({
    required this.id,
    required this.name,
    required this.sourceProgramName,
    required this.description,
    required this.level,
    required this.suggestedDays,
    required this.exercises,
  });

  int get exerciseCount => exercises.length;
}
