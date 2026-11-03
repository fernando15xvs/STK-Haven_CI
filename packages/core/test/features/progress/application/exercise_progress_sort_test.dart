import 'package:core/features/progress/application/exercise_progress_sort.dart';
import 'package:core/features/progress/application/exercise_progress_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 11, 3);
  int compare(
    ExerciseProgressOrder option, {
    String a = 'Press',
    String b = 'Curl',
    DateTime? aDate,
    DateTime? bDate,
    double? aChange,
    double? bChange,
  }) => compareExerciseProgress(
        order: option,
        firstName: a,
        secondName: b,
        firstDate: aDate ?? date,
        secondDate: bDate ?? date,
        firstChange: aChange,
        secondChange: bChange,
      );

  test('recent and inactive are reversed, alphabetical ignores volume', () {
    expect(compare(ExerciseProgressOrder.recent,
      aDate: date.subtract(const Duration(days: 2)),
      bDate: date), greaterThan(0));
    expect(compare(ExerciseProgressOrder.inactive,
      aDate: date.subtract(const Duration(days: 2)),
      bDate: date), lessThan(0));
    expect(compare(ExerciseProgressOrder.alphabetical), greaterThan(0));
  });

  test('improvement and decline never mistake missing comparison as zero', () {
    expect(compare(ExerciseProgressOrder.improvement,
        aChange: 10, bChange: -5), lessThan(0));
    expect(compare(ExerciseProgressOrder.decline,
        aChange: 10, bChange: -5), greaterThan(0));
    expect(compare(ExerciseProgressOrder.improvement,
        aChange: null, bChange: 5), greaterThan(0));
    expect(compare(ExerciseProgressOrder.decline,
        aChange: 0, bChange: null), lessThan(0));
    expect(compare(ExerciseProgressOrder.improvement,
        aChange: null, bChange: null), greaterThan(0));
  });

  test('all four selectable trends read their actual recorded values', () {
    final w = [ExerciseProgressPoint(date: date, value: 20)];
    final reps = [ExerciseProgressPoint(date: date, value: 8)];
    final rir = [ExerciseProgressPoint(date: date, value: 2)];
    final e1rm = [ExerciseProgressPoint(date: date, value: 25.3)];
    final trend = ExerciseProgressTrend(
      current1RM: 25.3,
      historyWeight: w,
      historyReps: reps,
      historyRir: rir,
      history1RM: e1rm,
    );
    expect(ExerciseTrendMetric.weight.points(trend), w);
    expect(ExerciseTrendMetric.repetitions.points(trend), reps);
    expect(ExerciseTrendMetric.rir.points(trend), rir);
    expect(ExerciseTrendMetric.estimatedOneRm.points(trend), e1rm);
  });
}
