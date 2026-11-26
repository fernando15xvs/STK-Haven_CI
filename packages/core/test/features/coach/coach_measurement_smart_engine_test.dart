import 'package:core/domain/models/body_measurement.dart';
import 'package:core/domain/models/coach_client_progress.dart';
import 'package:core/domain/models/coach_checkin.dart';
import 'package:core/domain/models/coach_exercise_progress.dart';
import 'package:core/features/coach/application/coach_measurement_provider.dart';
import 'package:core/features/coach/domain/smart_coach_engine.dart';
import 'package:test/test.dart';

final now=DateTime.utc(2026,11,26);
CoachClientProgress progress({DateTime? generatedAt,bool baseline=true,int workouts=3,int previous=4})=>CoachClientProgress(
  workouts7d:workouts,workouts30d:10,trainingMinutes7d:100,completedWorkingSets7d:15,
  volume7d:700,generatedAt:generatedAt??now,trendBaselineAvailable:baseline,
  workoutsPrevious7d:previous,completedWorkingSetsPrevious7d:12,volumePrevious7d:400,
);
CoachExerciseProgressSummary exercise({int sessions=4,double current=110,double previous=100})=>CoachExerciseProgressSummary(
  exerciseId:'exercise',exerciseName:'Remo',muscleGroup:'Espalda',lastPerformedAt:now,generatedAt:now,
  sessions30d:sessions,workingSets30d:12,volume30d:200,averageRir30d:2,
  sessionsPrevious30d:4,workingSetsPrevious30d:12,volumePrevious30d:200,
  bestEstimated1Rm30d:current,bestEstimated1RmPrevious30d:previous,bestWeight:null,bestWeightAt:null,
  bestEstimated1Rm:null,bestEstimated1RmAt:null,bestSetVolume:null,bestSetVolumeAt:null,
);
void main(){
  test('measurement export excludes id, invalid values and absent fields',(){
    final values=coachMeasurementValues(BodyMeasurement(id:'private',date:now,weightKg:70,
      waistCm:80,leftArmCm:double.nan,bodyFatPercentage:101,chestCm:0));
    expect(values,{'weightKg':70.0,'waistCm':80.0});
    expect(values.containsKey('id'),isFalse);
  });
  test('strict measurement parser rejects wrong relationship or private fields',(){
    final payload={'relationship_id':'r','measured_at':now.toIso8601String(),'shared_at':now.toIso8601String(),
      'values':{'waistCm':80}};
    expect(CoachMeasurementShare.fromJson(payload,'r').values,{'waistCm':80.0});
    expect(()=>CoachMeasurementShare.fromJson(payload,'other'),throwsFormatException);
    expect(()=>CoachMeasurementShare.fromJson({...payload,'values':{'note':'private'}},'r'),throwsFormatException);
    expect(()=>CoachMeasurementShare.fromJson({...payload,'values':{'waistCm':-1}},'r'),throwsFormatException);
  });
  test('no recommendations from missing, stale or insufficient summary',(){
    expect(SmartCoachEngine.progress(null,now:now).single.kind,SmartCoachKind.insufficient);
    expect(SmartCoachEngine.progress(progress(generatedAt:now.subtract(const Duration(days:4))),now:now).single.kind,SmartCoachKind.stale);
    expect(SmartCoachEngine.progress(progress(baseline:false),now:now).single.kind,SmartCoachKind.insufficient);
  });
  test('frequency and volume observations expose evidence without applying changes',(){
    final result=SmartCoachEngine.progress(progress(),now:now);
    expect(result.map((item)=>item.kind),containsAll([SmartCoachKind.frequency,SmartCoachKind.volume]));
    expect(result.every((item)=>item.evidence.isNotEmpty&&item.recommendation.isNotEmpty),isTrue);
  });
  test('exercise progression and plateau require enough observations',(){
    expect(SmartCoachEngine.exercise(exercise(sessions:1),now:now),isEmpty);
    expect(SmartCoachEngine.exercise(exercise(),now:now).single.kind,SmartCoachKind.progression);
    expect(SmartCoachEngine.exercise(exercise(current:101),now:now).single.kind,SmartCoachKind.plateau);
  });
  test('recovery observation is optional and never diagnoses',(){
    final item=CoachCheckin(id:'i',relationshipId:'r',coachUserId:'c',clientUserId:'u',energy:2,recovery:3,note:'private',createdAt:now);
    final result=SmartCoachEngine.recovery(item,now:now).single;
    expect(result.kind,SmartCoachKind.recovery);
    expect(result.evidence, isNot(contains('private')));
    expect(result.recommendation,contains('No es un diagnóstico'));
    expect(SmartCoachEngine.recovery(item,now:now.add(const Duration(days:4))),isEmpty);
  });
}
