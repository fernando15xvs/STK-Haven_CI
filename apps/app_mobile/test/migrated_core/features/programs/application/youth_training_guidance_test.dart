import 'dart:io';

import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/programs/application/youth_training_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
  final now=DateTime(2026,11,16);

  UserExperienceProfile youth({
    TrainingExperience? experience, int? days,
  })=>UserExperienceProfile(
    dateOfBirth:DateTime(2010,7,5),
    trainingExperience:experience,
    trainingDaysPerWeek:days,
  );

  test('a declared adult does not receive a youth safety claim',(){
    final adult=UserExperienceProfile(
      dateOfBirth:DateTime(1998,4,1),
      trainingDaysPerWeek:6,
      trainingExperience:TrainingExperience.beginner,
    );
    expect(YouthTrainingGuidance.forProfile(adult,now),isNull);
    expect(YouthTrainingGuidance.forProfile(null,now),isNull);
  });

  test('newer youth with many training days sees technique and recovery guidance',(){
    final beginner=youth(experience:TrainingExperience.beginner,days:6);
    final message=YouthTrainingGuidance.forProfile(beginner,now)!;
    expect(message,contains('Estás empezando'));
    expect(message,contains('descansar'));
    expect(message,contains('técnica'));
    expect(beginner.trainingDaysPerWeek,6); // No mutation or auto cap.
    expect(beginner.trainingExperience,TrainingExperience.beginner);
  });

  test('experienced youth with high frequency sees recovery and gradual loading',(){
    final message=YouthTrainingGuidance.forProfile(
      youth(experience:TrainingExperience.advanced,days:5),now)!;
    expect(message,contains('frecuencia elevada'));
    expect(message,contains('recuperarte'));
    expect(message,contains('gradualmente'));
  });

  test('youth with moderate schedule still sees safe, non-prescriptive guidance',(){
    final message=YouthTrainingGuidance.forProfile(
      youth(experience:TrainingExperience.intermediate,days:3),now)!;
    expect(message,contains('Prioriza técnica, progresión gradual y recuperación.'));
    expect(message,isNot(contains('calorías')));
  });

  test('missing date remains optional and never triggers adult scheduling',(){
    const profile=UserExperienceProfile(
      trainingDaysPerWeek:6,
      trainingExperience:TrainingExperience.advanced,
    );
    final message=YouthTrainingGuidance.forProfile(profile,now)!;
    expect(message,contains('sin indicar tu edad'));
    expect(message,contains('No se instalará automáticamente un programa adulto.'));
    expect(profile.dateOfBirth,isNull);
  });

  test('program manager and preferences reuse the same safe message',(){
    final programs=File(
      'lib/features/programs/presentation/pages/training_programs_page.dart',
    ).readAsStringSync();
    final preferences=File(
      'lib/features/profile/presentation/pages/personal_profile_page.dart',
    ).readAsStringSync();
    expect(programs,contains('YouthTrainingGuidance.forProfile('));
    expect(preferences,contains('YouthTrainingGuidance.forProfile('));
    expect(programs,contains("ValueKey('training_age_safety_guidance')"));
    expect(preferences,contains("ValueKey('experience_youth_rest_guidance')"));
    expect(programs,contains('Expanded(child:programs.isEmpty'));
    expect(preferences,contains('draft.copyWith(trainingDaysPerWeek: day)'));
  });
}
