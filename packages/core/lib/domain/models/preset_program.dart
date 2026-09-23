class PresetRoutineExercise {
  final String exerciseId;
  final int targetSets;
  final int targetRepsMin;
  final int targetRepsMax;
  final int restSeconds;

  const PresetRoutineExercise({
    required this.exerciseId,
    required this.targetSets,
    required this.targetRepsMin,
    required this.targetRepsMax,
    required this.restSeconds,
  });
}

class PresetRoutine {
  final String name;
  final List<int> scheduledDays; // e.g., 1=Mon, 2=Tue, etc.
  final List<PresetRoutineExercise> exercises;

  const PresetRoutine({
    required this.name,
    required this.scheduledDays,
    required this.exercises,
  });
}

class PresetProgram {
  final String id;
  final int version;
  final String name;
  final String description;
  final String level; // Beginner, Intermediate, Advanced
  final int daysPerWeek;
  final int durationWeeks;
  final List<PresetRoutine> routines;

  const PresetProgram({
    required this.id,
    required this.version,
    required this.name,
    required this.description,
    required this.level,
    required this.daysPerWeek,
    required this.durationWeeks,
    required this.routines,
  });
}
