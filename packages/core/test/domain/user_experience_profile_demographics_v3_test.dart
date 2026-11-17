import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy profile does not invent an age or equation parameter', () {
    final p = UserExperienceProfile.fromJson(const {
      'onboardingVersion': 2,
      'trainingDaysPerWeek': 4,
      'faithPreference': 'disabled',
    });
    expect(p.dateOfBirth, isNull);
    expect(p.genderIdentity, isNull);
    expect(p.equationSexForEnergy, isNull);
    expect(p.trainingDaysPerWeek, 4);
    expect(p.faithEnabled, isFalse);
  });

  test('optional private date, gender and equation survive backup JSON', () {
    final p = UserExperienceProfile(
      dateOfBirth: DateTime(2008, 11, 15),
      genderIdentity: GenderIdentity.nonBinary,
      equationSexForEnergy: EnergyEquationSex.female,
      onboardingVersion: UserExperienceProfile.currentOnboardingVersion,
    );
    final restored = UserExperienceProfile.fromJson(p.toJson());
    expect(restored.ageAt(DateTime(2026, 11, 14)), 17);
    expect(restored.ageAt(DateTime(2026, 11, 15)), 18);
    expect(restored.genderIdentity, GenderIdentity.nonBinary);
    expect(restored.equationSexForEnergy, EnergyEquationSex.female);
    expect(restored.toJson()['dateOfBirth'], '2008-11-15');
  });

  test('15+ eligibility date is retained independently of optional demographics', () {
    final p = UserExperienceProfile(
      eligibilityBirthDate: DateTime(2011, 11, 17),
      optionalDemographicsConsented: false,
    );
    expect(p.dateOfBirth, isNull);
    expect(p.ageAt(DateTime(2026, 11, 16)), 14);
    expect(p.ageAt(DateTime(2026, 11, 17)), 15);
    final restored = UserExperienceProfile.fromJson(p.toJson());
    expect(restored.eligibilityBirthDate, DateTime(2011, 11, 17));
    expect(restored.dateOfBirth, isNull);
    expect(restored.optionalDemographicsConsented, isFalse);
    final changedOptional = restored.copyWith(
      genderIdentity: GenderIdentity.nonBinary,
      optionalDemographicsConsented: false,
    );
    expect(changedOptional.eligibilityBirthDate, DateTime(2011, 11, 17));
    expect(changedOptional.ageAt(DateTime(2026, 11, 17)), 15);
    expect(changedOptional.copyWith(clearEligibilityBirthDate: true)
        .eligibilityBirthDate, isNull);
  });

  test('birthday 29 February does not prematurely age in a non-leap year', () {
    final p = UserExperienceProfile(dateOfBirth: DateTime(2008, 2, 29));
    expect(p.ageAt(DateTime(2026, 2, 28)), 17);
    expect(p.ageAt(DateTime(2026, 3, 1)), 18);
  });

  test('invalid, future and malformed dates never create false adult ages', () {
    expect(UserExperienceProfile.fromJson(const {
      'dateOfBirth': '3027-01-01',
    }).dateOfBirth, isNull);
    expect(UserExperienceProfile.fromJson(const {
      'dateOfBirth': '2026-02-31',
    }).dateOfBirth, isNull);
    expect(UserExperienceProfile.fromJson(const {
      'genderIdentity': 'arbitrary',
      'equationSexForEnergy': 'unknown',
    }).equationSexForEnergy, isNull);
  });

  test('clearing optional profile data is explicit', () {
    final p = UserExperienceProfile(
      dateOfBirth: DateTime(2001, 3, 2),
      genderIdentity: GenderIdentity.man,
      equationSexForEnergy: EnergyEquationSex.male,
    );
    final cleared = p.copyWith(
      clearDateOfBirth: true,
      clearGenderIdentity: true,
      clearEquationSexForEnergy: true,
    );
    expect(cleared.dateOfBirth, isNull);
    expect(cleared.genderIdentity, isNull);
    expect(cleared.equationSexForEnergy, isNull);
  });
}
