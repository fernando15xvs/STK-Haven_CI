import 'package:core/core/utils/fitness_math.dart';
import 'package:core/core/constants/curated_exercise_catalog.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/exercise_performance_memory.dart';

class OneRmCalculator {
  const OneRmCalculator._();

  static double epley({required double weight, required int reps}) {
    if (weight <= 0 || reps <= 0) return 0;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  static double brzycki({required double weight, required int reps}) {
    if (weight <= 0 || reps <= 0 || reps >= 37) return 0;
    if (reps == 1) return weight;
    return weight * 36.0 / (37.0 - reps);
  }

  static double estimate({required double weight, required int reps}) {
    return FitnessMath.estimated1RM(weight, reps) ?? 0;
  }

  static Map<int, double> percentageTable(double oneRm) {
    if (!oneRm.isFinite || oneRm <= 0) return const {};
    return {
      for (final pct in const [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50])
        pct: oneRm * pct / 100.0,
    };
  }
}

enum TrainingToolKind { oneRm, timer, plates }

class ExerciseToolAdvice {
  final List<TrainingToolKind> primary;
  final String reason;

  const ExerciseToolAdvice({required this.primary, required this.reason});
}

class ExerciseToolAdvisor {
  const ExerciseToolAdvisor._();

  static ExerciseToolAdvice forExercise(Exercise exercise) {
    final definition = CuratedExerciseCatalog.byId[exercise.id];
    final equipment = (definition?.equipment ?? exercise.equipment).toLowerCase();
    final name = exercise.name.toLowerCase();
    final description = '$name ${definition?.movementPattern ?? ''}';
    final timed = description.contains('plancha') || description.contains('plank') ||
        description.contains('isométr') || description.contains('isometric') ||
        description.contains('farmer') || description.contains('carry') ||
        description.contains('cardio') || description.contains('estiramiento');
    final usesBarbell = !equipment.contains('smith') &&
        !equipment.contains('máquina') && !equipment.contains('machine') &&
        (equipment == 'barra' || equipment.contains('barra olímp') ||
         equipment.contains('barra libre') || equipment.contains('barbell') ||
         (equipment.isEmpty && (name.contains('con barra') || name.contains('barbell'))));
    if (timed || definition?.mechanics == ExerciseMechanics.stability) {
      return const ExerciseToolAdvice(primary: [TrainingToolKind.timer],
        reason: 'Ejercicio por tiempo o control.');
    }
    if (usesBarbell) {
      return const ExerciseToolAdvice(primary: [TrainingToolKind.plates, TrainingToolKind.oneRm],
        reason: 'Carga de barra libre e intensidad estimada.');
    }
    final loadable = equipment.contains('mancuerna') || equipment.contains('dumbbell') ||
        equipment.contains('máquina') || equipment.contains('machine') ||
        equipment.contains('polea') || equipment.contains('cable') ||
        equipment.contains('smith') || equipment.contains('kettlebell');
    return ExerciseToolAdvice(
      primary: loadable ? const [TrainingToolKind.oneRm] : const [],
      reason: loadable ? 'Estimación de intensidad con carga registrada.' :
          'Sin herramienta específica para este ejercicio.',
    );
  }
}

/// Select the actual active working reference or latest completed memory.
class TrainingToolReference {
  static WorkoutSet? forExercise(WorkoutExercise exercise,
      ExercisePerformanceMemoryEntry? memory) {
    WorkoutSet? reference;

    for (final set in exercise.sets) {
      if (set.setType == WorkoutSetType.working &&
          set.performanceWeight > 0 &&
          set.performanceReps > 0 &&
          !set.completed) {
        reference = set;
        break;
      }
    }
    if (reference == null) {
      for (final set in exercise.sets.reversed) {
        if (set.setType == WorkoutSetType.working &&
            set.completed &&
            set.performanceWeight > 0 &&
            set.performanceReps > 0) {
          reference = set;
          break;
        }
      }
    }
    return reference ?? memory?.latestRepresentativeSet;
  }
}
