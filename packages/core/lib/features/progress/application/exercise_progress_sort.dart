import 'package:core/features/progress/application/exercise_progress_calculator.dart';

/// Sorting is presentation-only: no PR or session data is changed.
enum ExerciseProgressOrder {
  recent('Recientes'),
  alphabetical('Alfabético'),
  improvement('Mayor mejora'),
  decline('Mayor descenso'),
  inactive('Inactividad');

  const ExerciseProgressOrder(this.label);
  final String label;
}

enum ExerciseTrendMetric {
  weight('Peso'),
  repetitions('Reps'),
  rir('RIR'),
  estimatedOneRm('e1RM');

  const ExerciseTrendMetric(this.label);
  final String label;

  List<ExerciseProgressPoint> points(ExerciseProgressTrend trend) =>
      switch (this) {
        ExerciseTrendMetric.weight => trend.historyWeight,
        ExerciseTrendMetric.repetitions => trend.historyReps,
        ExerciseTrendMetric.rir => trend.historyRir,
        ExerciseTrendMetric.estimatedOneRm => trend.history1RM,
      };
}

/// Pure, stable comparator: no percentage is fabricated when only one
/// session exists. Those entries sort after comparable improvements/declines.
int compareExerciseProgress({
  required ExerciseProgressOrder order,
  required String firstName,
  required DateTime? firstDate,
  required double? firstChange,
  required String secondName,
  required DateTime? secondDate,
  required double? secondChange,
}) {
  final byName = firstName.toLowerCase().compareTo(secondName.toLowerCase());
  final aDate = firstDate ?? DateTime(1970);
  final bDate = secondDate ?? DateTime(1970);
  return switch (order) {
    ExerciseProgressOrder.recent =>
      bDate.compareTo(aDate) != 0 ? bDate.compareTo(aDate) : byName,
    ExerciseProgressOrder.alphabetical => byName,
    ExerciseProgressOrder.inactive =>
      aDate.compareTo(bDate) != 0 ? aDate.compareTo(bDate) : byName,
    ExerciseProgressOrder.improvement => _byChange(
      firstChange, secondChange, descending: true, tie: byName),
    ExerciseProgressOrder.decline => _byChange(
      firstChange, secondChange, descending: false, tie: byName),
  };
}

int _byChange(double? a, double? b,
    {required bool descending, required int tie}) {
  if (a == null || !a.isFinite) return b == null || !b.isFinite ? tie : 1;
  if (b == null || !b.isFinite) return -1;
  final c = descending ? b.compareTo(a) : a.compareTo(b);
  return c == 0 ? tie : c;
}
