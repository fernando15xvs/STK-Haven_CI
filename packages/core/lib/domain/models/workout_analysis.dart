import 'personal_record.dart';
import 'progression_suggestion.dart';
import 'workout_session.dart';

class SessionComparison {
  final double previousVolume;
  final double volumeDifferencePercent;
  final int setsDifference;
  final int durationDifferenceSeconds;

  SessionComparison({
    required this.previousVolume,
    required this.volumeDifferencePercent,
    required this.setsDifference,
    required this.durationDifferenceSeconds,
  });
}

/// Descriptive comparison between the exercise just completed and the newest
/// previous completed occurrence of the same global `exerciseId`.
///
/// Routine names are context only: identity is always exerciseId. Volumes use
/// WorkoutSet.performedVolume so detailed unilateral sessions stay comparable
/// with legacy shared-value sessions.
class ExercisePerformanceComparison {
  final String exerciseId;
  final String exerciseName;
  final DateTime previousPerformedAt;
  final String previousRoutineName;
  final double currentVolume;
  final double previousVolume;
  final int currentWorkingSets;
  final int previousWorkingSets;
  final double currentBestWeight;
  final double previousBestWeight;

  const ExercisePerformanceComparison({
    required this.exerciseId,
    required this.exerciseName,
    required this.previousPerformedAt,
    required this.previousRoutineName,
    required this.currentVolume,
    required this.previousVolume,
    required this.currentWorkingSets,
    required this.previousWorkingSets,
    required this.currentBestWeight,
    required this.previousBestWeight,
  });

  double? get volumeDifferencePercent {
    if (previousVolume <= 0) return null;
    return ((currentVolume - previousVolume) / previousVolume) * 100;
  }

  double get bestWeightDifference => currentBestWeight - previousBestWeight;
  int get workingSetsDifference => currentWorkingSets - previousWorkingSets;
}

class WorkoutAnalysisResult {
  final WorkoutSession session;
  final double totalVolume;
  final int completedSetsCount;
  final int durationSeconds;
  final List<PersonalRecordEvent> personalRecords;
  final List<ProgressionSuggestion> progressionSuggestions;
  final List<ProgressionSuggestion> deloadSuggestions;
  final SessionComparison? comparison; // null if it's the first time doing this routine
  final List<ExercisePerformanceComparison> exerciseComparisons;

  WorkoutAnalysisResult({
    required this.session,
    required this.totalVolume,
    required this.completedSetsCount,
    required this.durationSeconds,
    required this.personalRecords,
    required this.progressionSuggestions,
    required this.deloadSuggestions,
    required this.comparison,
    this.exerciseComparisons = const [],
  });
}
