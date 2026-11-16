import 'package:core/domain/models/daily_steps_state.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/domain/models/workout_session.dart';

/// A cautious, optional starting point for an adult's self-reported activity.
/// This never enables adult access, determines calories, or changes a plan.
class AdultActivitySuggestion {
  const AdultActivitySuggestion({
    required this.level,
    required this.medianSteps,
    required this.recordedStepDays,
    required this.recordedTrainingDays,
  });

  final EnergyActivityLevel level;
  final int medianSteps;
  final int recordedStepDays;
  final int recordedTrainingDays;

  String get label => switch(level){
    EnergyActivityLevel.sedentary=>'baja',
    EnergyActivityLevel.light=>'ligera',
    EnergyActivityLevel.moderate=>'moderada',
    EnergyActivityLevel.high=>'alta',
    EnergyActivityLevel.veryHigh=>'muy alta',
  };
}

class AdultActivitySuggestionPolicy {
  const AdultActivitySuggestionPolicy._();

  /// At least seven distinct sensor days plus two *completed* training days
  /// in the last 14 calendar days. Manual values or uncompleted plans aren't
  /// strong enough evidence. Training sessions are a confidence check only:
  /// we never add them on top of step counts (no double counting).
  static AdultActivitySuggestion? suggest({
    required Iterable<DailyStepsState> recordedSteps,
    required Iterable<WorkoutSession> sessions,
    required DateTime now,
  }) {
    final today=DateTime(now.year,now.month,now.day);
    final beginning=today.subtract(const Duration(days:13));
    final byDate=<String,int>{};
    for(final reading in recordedSteps){
      final date=DateTime.tryParse(reading.dateString);
      if(date==null || !reading.deviceSynced ||
         reading.lastSyncedAt==null ||
         reading.steps<1000 || reading.steps>35000)continue;
      final localDate=DateTime(date.year,date.month,date.day);
      if(localDate.isBefore(beginning)||localDate.isAfter(today))continue;
      byDate[reading.dateString]=reading.steps;
    }
    if(byDate.length<7)return null;

    final exerciseDays=<String>{};
    for(final session in sessions){
      final start=session.startedAt.toLocal();
      final day=DateTime(start.year,start.month,start.day);
      if(day.isBefore(beginning)||day.isAfter(today)||
         session.durationSeconds<600 ||
         session.finishedAt.isBefore(session.startedAt) ||
         session.finishedAt.isAfter(now) ||
         !session.exercises.any((exercise)=>
           exercise.sets.any((set)=>
             set.completed && set.setType==WorkoutSetType.working)))continue;
      final key='${day.year}-${day.month.toString().padLeft(2,'0')}-'
        '${day.day.toString().padLeft(2,'0')}';
      exerciseDays.add(key);
    }
    if(exerciseDays.length<2)return null;

    final sorted=byDate.values.toList()..sort();
    final mid=sorted.length~/2;
    final median=sorted.length.isOdd?sorted[mid]:
      ((sorted[mid-1]+sorted[mid])/2).round();
    // Never assert high/veryHigh from steps and strength sessions alone.
    // Everyday activities outside the phone and training intensity are
    // unmeasured and must always be confirmed by the user.
    final level=median>=8500
      ?EnergyActivityLevel.moderate
      :median>=4500
        ?EnergyActivityLevel.light
        :EnergyActivityLevel.sedentary;
    return AdultActivitySuggestion(
      level:level,medianSteps:median,recordedStepDays:byDate.length,
      recordedTrainingDays:exerciseDays.length,
    );
  }
}
