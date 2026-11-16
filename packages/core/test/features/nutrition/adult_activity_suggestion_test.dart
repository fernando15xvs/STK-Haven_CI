import 'package:core/domain/models/daily_steps_state.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/nutrition/application/adult_activity_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
  final now=DateTime(2026,11,16,12);

  List<DailyStepsState> sensorDays(int steps,{int count=7})=>[
    for(var i=0;i<count;i++)
      DailyStepsState(
        dateString:_date(now.subtract(Duration(days:i))),
        steps:steps,deviceSynced:true,
        lastSyncedAt:now.subtract(Duration(days:i)),
      ),
  ];
  WorkoutSession completedOn(int daysBack,{
    bool completed=true,
    bool working=true,
    int duration=1800,
  }){
    final start=now.subtract(Duration(days:daysBack,hours:2));
    return WorkoutSession(
      id:'session-$daysBack',routineNameSnapshot:'A',
      startedAt:start,finishedAt:start.add(Duration(seconds:duration)),
      durationSeconds:duration,
      exercises:[
        WorkoutExercise(exerciseId:'e',exerciseNameSnapshot:'Press',
          muscleGroupSnapshot:'Pecho',sets:[
            WorkoutSet(weight:10,reps:8,completed:completed,
              setType:working?WorkoutSetType.working:WorkoutSetType.warmup),
          ]),
      ],
    );
  }
  final training=[completedOn(0),completedOn(3)];

  test('does not guess activity from fewer than seven sensor days',(){
    final result=AdultActivitySuggestionPolicy.suggest(
      recordedSteps:sensorDays(8500,count:6),sessions:training,now:now);
    expect(result,isNull);
  });

  test('never treats manual, future or duplicate days as evidence',(){
    final base=sensorDays(8500,count:6);
    final invalid=[
      ...base,
      DailyStepsState(dateString:base[0].dateString,
        steps:9000,deviceSynced:true,lastSyncedAt:now),
      DailyStepsState(dateString:_date(now.add(const Duration(days:1))),
        steps:10000,deviceSynced:true,lastSyncedAt:now),
      DailyStepsState(dateString:_date(now.subtract(const Duration(days:7))),
        steps:5000,deviceSynced:false),
    ];
    expect(AdultActivitySuggestionPolicy.suggest(
      recordedSteps:invalid,sessions:training,now:now),isNull);
  });

  test('incomplete, warm-up-only, duplicate-day or very short workouts are not proof',(){
    final invalidCases=[
      [completedOn(0),completedOn(0)],
      [completedOn(0),completedOn(3,completed:false)],
      [completedOn(0),completedOn(3,working:false)],
      [completedOn(0),completedOn(3,duration:300)],
      [completedOn(0)],
    ];
    for(final history in invalidCases){
      expect(AdultActivitySuggestionPolicy.suggest(
        recordedSteps:sensorDays(8500),sessions:history,now:now),isNull);
    }
  });

  test('offers only conservative activity bands from recorded median',(){
    for(final entry in <(int,EnergyActivityLevel)>[
      (3200,EnergyActivityLevel.sedentary),
      (6500,EnergyActivityLevel.light),
      (9000,EnergyActivityLevel.moderate),
      (25000,EnergyActivityLevel.moderate),
    ]){
      final suggestion=AdultActivitySuggestionPolicy.suggest(
        recordedSteps:sensorDays(entry.$1),sessions:training,now:now);
      expect(suggestion,isNotNull);
      expect(suggestion!.level,entry.$2);
      expect(suggestion.medianSteps,entry.$1);
      expect(suggestion.recordedStepDays,7);
      expect(suggestion.recordedTrainingDays,2);
      expect(suggestion.level,isNot(EnergyActivityLevel.high));
      expect(suggestion.level,isNot(EnergyActivityLevel.veryHigh));
    }
  });

  test('suggestion never edits the existing energy plan',(){
    final suggestion=AdultActivitySuggestionPolicy.suggest(
      recordedSteps:sensorDays(6500),sessions:training,now:now);
    expect(suggestion,isNotNull);
    expect(suggestion!.label,'ligera');
    expect(suggestion.recordedStepDays,7);
    expect(suggestion.recordedTrainingDays,2);
    // The policy produces a value only. No mutation, profile write, or RPC.
    expect(suggestion.level,EnergyActivityLevel.light);
  });

  test('old history cannot impersonate two recent recorded sessions',(){
    final old=[completedOn(0),completedOn(20)];
    expect(AdultActivitySuggestionPolicy.suggest(
      recordedSteps:sensorDays(9000),sessions:old,now:now),isNull);
  });
}

String _date(DateTime dt)=>
  '${dt.year}-${dt.month.toString().padLeft(2,'0')}-'
  '${dt.day.toString().padLeft(2,'0')}';
