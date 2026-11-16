import 'dart:io';

import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/nutrition/application/wellness_rest_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
  final today=DateTime(2026,11,16,12);
  WorkoutSession session(DateTime finish,{bool completed=true}){
    return WorkoutSession(
      id:'test',routineNameSnapshot:'Rutina',
      startedAt:finish.subtract(const Duration(minutes:40)),
      finishedAt:finish,durationSeconds:2400,
      exercises:[
        WorkoutExercise(exerciseId:'1',exerciseNameSnapshot:'Press',
          muscleGroupSnapshot:'Pecho',sets:[
            WorkoutSet(weight:20,reps:8,completed:completed),
          ]),
      ],
    );
  }

  test('unknown profile does not claim today is a scheduled rest day',(){
    final msg=WellnessRestGuidance.forToday(
      profile:null,sessions:const <WorkoutSession>[],now:today);
    expect(msg,contains('no suponemos cuáles'));
    expect(msg,isNot(contains('calorías')));
  });

  test('a youth profile receives non-caloric rest and technique guidance',(){
    final msg=WellnessRestGuidance.forToday(
      profile:UserExperienceProfile(
        dateOfBirth:DateTime(2011,8,5),
        trainingDaysPerWeek:6,
      ),sessions:[session(today)],now:today);
    expect(msg,contains('técnica'));
    expect(msg,contains('descanso'));
    expect(msg,contains('contar calorías'));
    expect(msg,isNot(contains('kcal')));
  });

  test('no completed workout today is only a possible rest day',(){
    final msg=WellnessRestGuidance.forToday(
      profile:const UserExperienceProfile(trainingDaysPerWeek:4),
      sessions:[session(today.subtract(const Duration(days:1)))],
      now:today);
    expect(msg,contains('podría ser'));
    expect(msg,contains('no lo asumimos'));
    expect(msg,contains('No necesitas compensarlo'));
  });

  test('completed training today changes advice without mutating a goal',(){
    final msg=WellnessRestGuidance.forToday(
      profile:const UserExperienceProfile(trainingDaysPerWeek:4),
      sessions:[session(today.subtract(const Duration(minutes:15)))],
      now:today);
    expect(msg,contains('sesión completada'));
    expect(msg,contains('no cambian automáticamente'));
  });

  test('daily training plans get a recovery caution, not a new target',(){
    final msg=WellnessRestGuidance.forToday(
      profile:const UserExperienceProfile(trainingDaysPerWeek:7),
      sessions:const <WorkoutSession>[],now:today);
    expect(msg,contains('recuperación también importa'));
    expect(msg,contains('sin presión'));
  });

  test('Nutrition uses read-only rest guidance without rewriting user goals',(){
    final source=File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    expect(source,contains('WellnessRestGuidance.forToday('));
    expect(source,contains("ValueKey('nutrition_wellness_rest_context')"));
    expect(source,contains('ref.watch(workoutHistoryProvider)'));
    expect(source,contains('ref.watch(userExperienceProfileProvider)'));
  });
}
