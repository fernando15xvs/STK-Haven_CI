import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/recovery/application/adaptive_recovery.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:core/features/recovery/application/sleep_diary.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026,11,27,10);
  final routine = Routine(id:'r',name:'Mi rutina',scheduledDays:[],createdAt:now,
    exercises: const [
      RoutineExercise(exerciseId:'leg',order:0,targetSets:4,targetRepsMin:8,targetRepsMax:12,restSeconds:90),
      RoutineExercise(exerciseId:'chest',order:1,targetSets:3,targetRepsMin:8,targetRepsMax:12,restSeconds:90),
      RoutineExercise(exerciseId:'warm',order:2,targetSets:3,targetRepsMin:8,targetRepsMax:12,restSeconds:90,phase:RoutineExercisePhase.mobility),
    ]);
  final exercises = [
    Exercise(id:'leg',name:'Sentadilla personal',muscleGroup:'Piernas'),
    Exercise(id:'chest',name:'Press personal',muscleGroup:'Pecho'),
    Exercise(id:'warm',name:'Movilidad',muscleGroup:'Piernas'),
  ];
  RecoveryCheckIn check({List<String> areas=const [], bool pain=false, int soreness=4}) =>
    RecoveryCheckIn(date:now,energy:5,sleep:5,stress:1,soreness:soreness,
      updatedAt:now,fatiguedAreas:areas,painReported:pain);

  test('missing sleep does not pretend to be zero; measured zero is distinct',(){
    final empty = SleepDiary.empty();
    expect(empty.average(now,7),isNull);
    final diary=empty.withEntry(now,0).withQuality(now,4)
      .withEntry(now.subtract(const Duration(days:1)),480);
    expect(diary.average(now,7),240);
    expect(SleepDiary.fromJson(diary.toJson()).qualityFor(now),4);
    expect(diary.withoutEntry(now).qualityFor(now),isNull);
    expect(SleepDiary.suggestedMinimumMinutes(16),480);
    expect(SleepDiary.suggestedMinimumMinutes(25),420);
    expect(SleepDiary.suggestedMinimumMinutes(null),isNull);
  });
  test('localized fatigue changes only relevant effective sets, never template',(){
    final advice=AdaptiveRecovery.evaluate(now:now,routine:routine,exercises:exercises,
      sleep:SleepDiary.empty(),checkIn:check(areas:['Piernas']));
    expect(advice.globalCaution,isFalse);
    expect(advice.reducedSets,{0:3});
    expect(advice.cautions('chest'),isFalse);
    expect(advice.adapt(routine).exercises.map((e)=>e.targetSets),[3,3,3]);
    expect(routine.exercises.first.targetSets,4);
  });
  test('pain cannot be averaged away and never offers set reduction as clearance',(){
    final value=check(pain:true,soreness:1);
    expect(value.status,RecoveryStatus.low);
    final advice=AdaptiveRecovery.evaluate(now:now,routine:routine,exercises:exercises,
      sleep:SleepDiary.empty(),checkIn:value);
    expect(advice.pain,isTrue);
    expect(advice.reducedSets,isEmpty);
    expect(RecoveryCheckIn.fromMap(value.toMap()).painReported,isTrue);
  });
  test('short sleep independently adds caution, even without a check-in',(){
    final advice=AdaptiveRecovery.evaluate(now:now,routine:routine,exercises:exercises,
      sleep:SleepDiary.empty().withEntry(now,240));
    expect(advice.globalCaution,isTrue);
    expect(advice.reducedSets,{0:3,1:2});
  });
  test('only completed working sets with actual RIR contribute effort signal',(){
    expect(AdaptiveRecovery.highEffort([const WorkoutSet(weight:20,reps:7,completed:true,rir:0,warmup:true)]),isFalse);
    expect(AdaptiveRecovery.highEffort([const WorkoutSet(weight:20,reps:7,completed:true,rir:0)]),isTrue);
  });
}
