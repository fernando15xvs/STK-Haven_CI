import 'package:core/domain/models/exercise.dart';
import 'package:core/core/utils/fitness_math.dart';
import 'package:core/features/workout/application/barbell_calculator.dart';
import 'package:core/features/tools/application/training_tools.dart';
import 'package:test/test.dart';

void main() {
  group('OneRmCalculator', () {
    test('returns exact load for a single rep', () {
      expect(OneRmCalculator.estimate(weight: 100, reps: 1), 100);
    });

    test('estimates multi-rep 1RM and builds percentages', () {
      final oneRm = OneRmCalculator.estimate(weight: 100, reps: 5);
      expect(oneRm, FitnessMath.estimated1RM(100,5));
      expect(oneRm, lessThan(119));
      final table = OneRmCalculator.percentageTable(oneRm);
      expect(table[100], closeTo(oneRm, 0.001));
      expect(table[80], closeTo(oneRm * 0.8, 0.001));
    });

    test('rejects invalid inputs', () {
      expect(OneRmCalculator.estimate(weight: 0, reps: 5), 0);
      expect(OneRmCalculator.estimate(weight: 100, reps: 0), 0);
      expect(OneRmCalculator.percentageTable(0), isEmpty);
      expect(OneRmCalculator.estimate(weight:100,reps:11),0);
      expect(OneRmCalculator.estimate(weight:double.infinity,reps:3),0);
      expect(OneRmCalculator.percentageTable(double.nan),isEmpty);
    });
  });

  test('balanced plates respect stock and maximize attainable load',(){
    final result=BarbellCalculator.calculate(targetWeight:56,barWeight:20,
      availablePlates:const [10,9],inventory:{10:2,9:4});
    expect(result.actualTotalWeight,56);
    expect(result.platesPerSide.map((p)=>p.weight),[9,9]);
    expect(result.exact,isTrue);
    final short=BarbellCalculator.calculate(targetWeight:15);
    expect(short.belowBar,isTrue);
    expect(short.remainder,-5);
    final limited=BarbellCalculator.calculate(targetWeight:100,inventory:{20:3});
    expect(limited.actualTotalWeight,60);
    expect(limited.exact,isFalse);
  });
  test('invalid and zero plate sizes cannot stall the solver',(){
    expect(()=>BarbellCalculator.calculate(targetWeight:double.infinity),throwsArgumentError);
    expect(BarbellCalculator.calculate(targetWeight:40,
      availablePlates:[0,-1,double.nan,10]).actualTotalWeight,40);
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
      expect(advice.primary, [TrainingToolKind.timer]);
    });
  });
}
