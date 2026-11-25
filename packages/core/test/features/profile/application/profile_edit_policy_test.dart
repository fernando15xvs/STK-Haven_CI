import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/application/profile_edit_policy.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026,11,25);
  final original = UserExperienceProfile(displayName:'Original', avatarPhotoBase64:'AQID',
    dateOfBirth:DateTime(2000,2,3), eligibilityBirthDate:DateTime(2001,4,5),
    optionalDemographicsConsented:true, optionalDemographicsConsentedAt:DateTime(2025),
    trainingDaysPerWeek:5, onboardingVersion:3, faithPreference:FaithContentPreference.enabled);
  UserExperienceProfile merge(UserExperienceProfile draft, {UserExperienceProfile? current}) =>
    ProfileEditPolicy.merge(original:original,draft:draft,current:current??original,now:now);
  test('unified save preserves identity, eligibility and unrelated concurrent fields', () {
    final updated=merge(original.copyWith(displayName:' Nuevo ',trainingGoal:TrainingGoal.strength,
      faithPreference:FaithContentPreference.disabled,capabilities:{UserCapability.coach}),
      current:original.copyWith(weightUnit:WeightUnit.lb,habitsEnabled:true,
        legacyTrainingFollowupDismissed:true));
    expect(updated.displayName,'Nuevo');
    expect(updated.trainingGoal,TrainingGoal.strength);
    expect(updated.faithEnabled,isFalse);
    expect(updated.capabilities,{UserCapability.coach});
    expect(updated.avatarPhotoBase64,'AQID');
    expect(updated.eligibilityBirthDate,original.eligibilityBirthDate);
    expect(updated.optionalDemographicsConsentedAt,original.optionalDemographicsConsentedAt);
    expect(updated.weightUnit,WeightUnit.lb);
    expect(updated.habitsEnabled,isTrue);
    expect(updated.legacyTrainingFollowupDismissed,isTrue);
    expect(updated.onboardingVersion,3);
  });
  test('optional demographic withdrawal leaves eligibility and preferences intact', () {
    final updated=merge(original.copyWith(clearDateOfBirth:true,clearGenderIdentity:true,
      clearEquationSexForEnergy:true,optionalDemographicsConsented:false,
      clearOptionalDemographicsConsentAt:true));
    expect(updated.dateOfBirth,isNull);
    expect(updated.optionalDemographicsConsented,isFalse);
    expect(updated.optionalDemographicsUpdatedAt,now);
    expect(updated.eligibilityBirthDate,original.eligibilityBirthDate);
    expect(updated.trainingDaysPerWeek,5);
  });
  test('unchanged legacy unconsented data is preserved; new data requires permission', () {
    final legacy=original.copyWith(optionalDemographicsConsented:false,
      clearOptionalDemographicsConsentAt:true);
    final updated=ProfileEditPolicy.merge(original:legacy,
      draft:legacy.copyWith(displayName:'Otro'),current:legacy,now:now);
    expect(updated.dateOfBirth,legacy.dateOfBirth);
    expect(updated.optionalDemographicsConsented,isFalse);
    expect(()=>ProfileEditPolicy.merge(original:legacy,
      draft:legacy.copyWith(dateOfBirth:DateTime(2002)),current:legacy,now:now),throwsFormatException);
  });
  test('conflicting edits and concurrent consent withdrawal cannot be overwritten', () {
    expect(()=>merge(original.copyWith(displayName:'A'),current:original.copyWith(displayName:'B')),throwsStateError);
    expect(()=>merge(original.copyWith(dateOfBirth:DateTime(2002)),
      current:original.copyWith(clearDateOfBirth:true,optionalDemographicsConsented:false,
        clearOptionalDemographicsConsentAt:true)),throwsStateError);
  });
}
