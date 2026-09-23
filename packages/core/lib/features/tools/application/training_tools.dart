import 'package:core/domain/models/exercise.dart';

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
    final values = <double>[
      epley(weight: weight, reps: reps),
      brzycki(weight: weight, reps: reps),
    ].where((value) => value > 0).toList(growable: false);
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static Map<int, double> percentageTable(double oneRm) {
    if (oneRm <= 0) return const {};
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
    final haystack = '${exercise.name} ${exercise.equipment} ${exercise.instructions}'.toLowerCase();
    final usesBarbell = haystack.contains('barra') ||
        haystack.contains('barbell') ||
        haystack.contains('smith') ||
        haystack.contains('olímp');
    final isTimed = haystack.contains('plancha') ||
        haystack.contains('plank') ||
        haystack.contains('isométr') ||
        haystack.contains('farmer') ||
        haystack.contains('carry') ||
        haystack.contains('cardio');

    if (usesBarbell) {
      return const ExerciseToolAdvice(
        primary: [TrainingToolKind.plates, TrainingToolKind.oneRm, TrainingToolKind.timer],
        reason: 'Ejercicio con barra: prioriza discos y cálculo de intensidad.',
      );
    }
    if (isTimed) {
      return const ExerciseToolAdvice(
        primary: [TrainingToolKind.timer, TrainingToolKind.oneRm],
        reason: 'Ejercicio con componente de tiempo o isometría: temporizador primero.',
      );
    }
    return const ExerciseToolAdvice(
      primary: [TrainingToolKind.oneRm, TrainingToolKind.timer],
      reason: 'Accesos rápidos para estimar intensidad y controlar descansos.',
    );
  }
}
