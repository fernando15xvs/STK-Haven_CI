import 'package:core/core/constants/preset_programs.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/routine_template.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/routines/data/routine_repository.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

List<RoutineTemplate> buildRoutineTemplates() {
  final items = <RoutineTemplate>[];
  for (final program in presetPrograms) {
    for (var index = 0; index < program.routines.length; index++) {
      final routine = program.routines[index];
      items.add(
        RoutineTemplate(
          id: '${program.id}_$index',
          name: routine.name,
          sourceProgramName: program.name,
          description: program.description,
          level: program.level,
          suggestedDays: List<int>.unmodifiable(routine.scheduledDays),
          exercises: List.unmodifiable(routine.exercises),
        ),
      );
    }
  }
  return List.unmodifiable(items);
}

final routineTemplateServiceProvider = Provider<RoutineTemplateService>((ref) {
  return RoutineTemplateService(
    repository: ref.watch(routineRepositoryProvider),
    routineListNotifier: ref.watch(routineListProvider.notifier),
    exerciseListNotifier: ref.watch(exerciseListProvider.notifier),
  );
});

class RoutineTemplateService {
  final RoutineRepository repository;
  final RoutineListNotifier routineListNotifier;
  final ExerciseListNotifier exerciseListNotifier;

  RoutineTemplateService({
    required this.repository,
    required this.routineListNotifier,
    required this.exerciseListNotifier,
  });

  List<RoutineTemplate> get templates => buildRoutineTemplates();

  Future<Routine> createFromTemplate(RoutineTemplate template) async {
    await exerciseListNotifier.ensureSeeded();

    const uuid = Uuid();
    final existing = repository.getAllRoutines();
    final name = _uniqueName(template.name, existing.map((r) => r.name));
    final createdAt = DateTime.now();

    final routine = Routine(
      id: uuid.v4(),
      name: name,
      scheduledDays: List<int>.from(template.suggestedDays),
      createdAt: createdAt,
      exercises: template.exercises.asMap().entries.map((entry) {
        final exercise = entry.value;
        return RoutineExercise(
          exerciseId: exercise.exerciseId,
          order: entry.key,
          targetSets: exercise.targetSets,
          targetRepsMin: exercise.targetRepsMin,
          targetRepsMax: exercise.targetRepsMax,
          restSeconds: exercise.restSeconds,
        );
      }).toList(growable: false),
    );

    await repository.addRoutine(routine);
    routineListNotifier.refresh();
    return routine;
  }

  String _uniqueName(String baseName, Iterable<String> existingNames) {
    final used = existingNames.map((name) => name.trim().toLowerCase()).toSet();
    if (!used.contains(baseName.trim().toLowerCase())) return baseName;

    var suffix = 2;
    while (used.contains('$baseName $suffix'.trim().toLowerCase())) {
      suffix++;
    }
    return '$baseName $suffix';
  }
}
