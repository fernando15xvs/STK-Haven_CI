class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final List<String> secondaryMuscles;
  final String equipment;
  final String instructions;
  final String media;

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.secondaryMuscles = const [],
    this.equipment = '',
    this.instructions = '',
    this.media = '',
  });
}
