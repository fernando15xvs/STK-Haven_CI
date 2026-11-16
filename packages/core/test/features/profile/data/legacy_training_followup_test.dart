import 'package:core/domain/models/user_experience_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy profiles receive only a voluntary training follow-up',(){
    const existing=UserExperienceProfile(
      displayName:'Ana',
      onboardingVersion:1,
      trainingGoal:TrainingGoal.strength,
      trainingDaysPerWeek:3,
      trainingExperience:TrainingExperience.beginner,
      // A legacy user never provided the environment question.
    );
    expect(existing.needsOptionalTrainingFollowup,isTrue);
    final dismissed=existing.copyWith(legacyTrainingFollowupDismissed:true);
    expect(dismissed.needsOptionalTrainingFollowup,isFalse);
    expect(dismissed.displayName,'Ana');
    expect(dismissed.trainingGoal,TrainingGoal.strength);
    expect(dismissed.trainingDaysPerWeek,3);
    expect(dismissed.trainingExperience,TrainingExperience.beginner);
    expect(dismissed.onboardingVersion,1);
    expect(UserExperienceProfile.fromJson(dismissed.toJson())
      .legacyTrainingFollowupDismissed,isTrue);
  });

  test('a fresh undecided profile is not mistaken for a migrated user',(){
    const fresh=UserExperienceProfile();
    expect(fresh.onboardingVersion,0);
    expect(fresh.needsOptionalTrainingFollowup,isFalse);
  });

  test('already answered training questions are never requested again',(){
    const complete=UserExperienceProfile(
      onboardingVersion:2,
      trainingGoal:TrainingGoal.hypertrophy,
      trainingExperience:TrainingExperience.intermediate,
      trainingDaysPerWeek:4,
      trainingEnvironment:TrainingEnvironment.fullGym,
    );
    expect(complete.needsOptionalTrainingFollowup,isFalse);
    expect(complete.copyWith(clearTrainingDays:true)
      .needsOptionalTrainingFollowup,isTrue);
    expect(complete.copyWith(onboardingVersion:
      UserExperienceProfile.currentOnboardingVersion,
      clearTrainingDays:true).needsOptionalTrainingFollowup,isFalse);
  });

  test('missing demographic values never force optional training or age grants',(){
    const current=UserExperienceProfile(
      onboardingVersion:3,
      planningPreference:PlanningPreference.selfDirected,
      // Date of birth, equation, gender and habits are optional.
    );
    expect(current.needsOptionalTrainingFollowup,isFalse);
    expect(current.dateOfBirth,isNull);
    expect(current.equationSexForEnergy,isNull);
    expect(current.genderIdentity,isNull);
    expect(current.toJson().containsKey('verifiedAdult'),isFalse);
  });

  test('legacy JSON migrates without changing other options or injecting answers',(){
    const older=UserExperienceProfile(
      displayName:'Leo',
      onboardingVersion:1,
      faithPreference:FaithContentPreference.enabled,
      capabilities:{UserCapability.athlete,UserCapability.coach},
      trainingGoal:TrainingGoal.activeLifestyle,
    );
    final json=older.toJson()..remove('legacyTrainingFollowupDismissed');
    final restored=UserExperienceProfile.fromJson(json);
    expect(restored.legacyTrainingFollowupDismissed,isFalse);
    expect(restored.needsOptionalTrainingFollowup,isTrue);
    expect(restored.trainingGoal,TrainingGoal.activeLifestyle);
    expect(restored.trainingExperience,isNull);
    expect(restored.faithPreference,FaithContentPreference.enabled);
    expect(restored.isCoach,isTrue);
    expect(restored.onboardingVersion,1);
  });
}
