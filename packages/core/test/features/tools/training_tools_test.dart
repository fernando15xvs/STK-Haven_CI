import 'package:core/domain/models/exercise.dart';
import 'package:core/features/tools/application/training_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OneRmCalculator', () {
    test('returns exact load for a single rep', () {
      expect(OneRmCalculator.estimate(weight: 100, reps: 1), 100);
    });

    test('estimates multi-rep 1RM and builds percentages', () {
      final oneRm = OneRmCalculator.estimate(weight: 100, reps: 5);
      expect(oneRm, greaterThan(112));
      expect(oneRm, lessThan(119));
      final table = OneRmCalculator.percentageTable(oneRm);
      expect(table[100], closeTo(oneRm, 0.001));
      expect(table[80], closeTo(oneRm * 0.8, 0.001));
    });

    test('rejects invalid inputs', () {
      expect(OneRmCalculator.estimate(weight: 0, reps: 5), 0);
      expect(OneRmCalculator.estimate(weight: 100, reps: 0), 0);
      expect(OneRmCalculator.percentageTable(0), isEmpty);
    });
  });

  group('ExerciseToolAdvisor', () {
    test('prioritizes plate calculator for barbell exercises', () {
      final advice = ExerciseToolAdvisor.forExercise(
        Exercise(id: 'sq', name: 'Sentadilla con barra', muscleGroup: 'Piernas', equipment: 'Barra olímpica'),
      );
      expect(advice.primary.first, TrainingToolKind.plates);
      expect(advice.primary, contains(TrainingToolKind.oneRm));
    });

    test('prioritizes timer for isometric exercises', () {
      final advice = ExerciseToolAdvisor.forExercise(
        Exercise(id: 'plank', name: 'Plancha isométrica', muscleGroup: 'Core'),
      );
      expect(advice.primary.first, TrainingToolKind.timer);
    });
  });
}
