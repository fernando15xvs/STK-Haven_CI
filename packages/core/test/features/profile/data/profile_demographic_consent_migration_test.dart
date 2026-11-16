import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('a fresh profile contains no implicit demographic consent',(){
    const profile=UserExperienceProfile();
    expect(profile.optionalDemographicsConsented,isFalse);
    expect(profile.optionalDemographicsConsentedAt,isNull);
    expect(profile.optionalDemographicsUpdatedAt,isNull);
    expect(profile.dateOfBirth,isNull);
  });

  test('old backups retain values, coach and faith without fabricating consent',(){
    final old=UserExperienceProfile(
      onboardingVersion:2,
      displayName:'Usuario',
      dateOfBirth:DateTime(1998,4,9),
      equationSexForEnergy:EnergyEquationSex.female,
      faithPreference:FaithContentPreference.enabled,
      capabilities:const {UserCapability.athlete,UserCapability.coach},
      trainingGoal:TrainingGoal.strength,
      trainingDaysPerWeek:3,
    ).toJson()
      ..remove('optionalDemographicsConsented')
      ..remove('optionalDemographicsConsentedAt')
      ..remove('optionalDemographicsUpdatedAt');
    final restored=UserExperienceProfile.fromJson(old);
    expect(restored.optionalDemographicsConsented,isFalse);
    expect(restored.optionalDemographicsConsentedAt,isNull);
    expect(restored.optionalDemographicsUpdatedAt,isNull);
    expect(restored.dateOfBirth?.year,1998);
    expect(restored.equationSexForEnergy,EnergyEquationSex.female);
    expect(restored.trainingDaysPerWeek,3);
    expect(restored.faithPreference,FaithContentPreference.enabled);
    expect(restored.isCoach,isTrue);
  });

  test('explicit local opt-in and edit timestamp survive JSON backup',(){
    final t=DateTime(2026,11,16,13);
    final saved=UserExperienceProfile(
      dateOfBirth:DateTime(2000,1,10),
      optionalDemographicsConsented:true,
      optionalDemographicsConsentedAt:t,
      optionalDemographicsUpdatedAt:t,
    );
    final restored=UserExperienceProfile.fromJson(saved.toJson());
    expect(restored.optionalDemographicsConsented,isTrue);
    expect(restored.optionalDemographicsConsentedAt,t);
    expect(restored.optionalDemographicsUpdatedAt,t);
    expect(restored.ageAt(t),26);
  });

  test('revoking consent and deleting personal fields retains training data',(){
    final date=DateTime(2026,11,16);
    final stored=UserExperienceProfile(
      displayName:'A',
      dateOfBirth:DateTime(2000,5,15),
      genderIdentity:GenderIdentity.nonBinary,
      equationSexForEnergy:EnergyEquationSex.male,
      optionalDemographicsConsented:true,
      optionalDemographicsConsentedAt:date,
      trainingExperience:TrainingExperience.beginner,
      trainingGoal:TrainingGoal.strength,
    );
    final cleared=stored.copyWith(
      optionalDemographicsConsented:false,
      clearOptionalDemographicsConsentAt:true,
      clearDateOfBirth:true,
      clearGenderIdentity:true,
      clearEquationSexForEnergy:true,
      optionalDemographicsUpdatedAt:date.add(const Duration(hours:1)),
    );
    final restored=UserExperienceProfile.fromJson(cleared.toJson());
    expect(restored.optionalDemographicsConsented,isFalse);
    expect(restored.optionalDemographicsConsentedAt,isNull);
    expect(restored.dateOfBirth,isNull);
    expect(restored.genderIdentity,isNull);
    expect(restored.equationSexForEnergy,isNull);
    expect(restored.optionalDemographicsUpdatedAt,
      date.add(const Duration(hours:1)));
    expect(restored.trainingGoal,TrainingGoal.strength);
    expect(restored.trainingExperience,TrainingExperience.beginner);
    expect(restored.displayName,'A');
  });
}
