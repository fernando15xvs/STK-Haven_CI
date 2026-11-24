import 'package:core/features/nutrition/application/stk_nutrition_capability_policy.dart';
import 'package:test/test.dart';

void main() {
  test('exactly three capabilities, but only two eligible age experiences', () {
    expect(StkNutritionCapability.values, hasLength(3));
    for (final age in <int?>[null, -2, 0, 14, 121]) {
      final result = StkNutritionCapabilityPolicy.resolve(
        declaredAge: age,
        backendAdultGranted: true,
        backendInformationalGranted: true,
        approvedLegalRelease: true,
        approvedClinicalReview: true,
        currentPhotoConsent: true,
      );
      expect(result.foodDescription, isFalse);
      expect(result.informationalFoodEstimate, isFalse);
      expect(result.personalizedAdultEnergy, isFalse);
    }
  });

  test('15–17 keeps descriptive access but never gets adult calorie goals', () {
    for (final age in [15, 16, 17]) {
      final defaultAccess = StkNutritionCapabilityPolicy.resolve(
        declaredAge: age,
        backendAdultGranted: true, // stale or misplaced adult grant
      );
      expect(defaultAccess.foodDescription, isTrue);
      expect(defaultAccess.informationalFoodEstimate, isFalse);
      expect(defaultAccess.personalizedAdultEnergy, isFalse);
      final reviewed = StkNutritionCapabilityPolicy.resolve(
        declaredAge: age,
        backendAdultGranted: true,
        backendInformationalGranted: true,
        approvedLegalRelease: true,
        approvedClinicalReview: true,
        currentPhotoConsent: true,
      );
      expect(reviewed.informationalFoodEstimate, isTrue);
      expect(reviewed.personalizedAdultEnergy, isFalse);
    }
  });

  test('informational estimates need ALL independent backend and release gates',
      () {
    for (final grant in [false, true]) {
      for (final legal in [false, true]) {
        for (final clinical in [false, true]) {
          for (final consent in [false, true]) {
            final actual = StkNutritionCapabilityPolicy.resolve(
              declaredAge: 16,
              backendAdultGranted: false,
              backendInformationalGranted: grant,
              approvedLegalRelease: legal,
              approvedClinicalReview: clinical,
              currentPhotoConsent: consent,
            );
            expect(actual.informationalFoodEstimate,
              grant && legal && clinical && consent);
            expect(actual.personalizedAdultEnergy, isFalse);
          }
        }
      }
    }
  });

  test('adults require an independent adult server grant', () {
    for (final age in [18, 21, 65, 120]) {
      final unverified = StkNutritionCapabilityPolicy.resolve(
        declaredAge: age,
        backendAdultGranted: false,
        backendInformationalGranted: true,
        approvedLegalRelease: true,
        approvedClinicalReview: true,
        currentPhotoConsent: true,
      );
      expect(unverified.foodDescription, isTrue);
      expect(unverified.personalizedAdultEnergy, isFalse);
      final authorized = StkNutritionCapabilityPolicy.resolve(
        declaredAge: age,
        backendAdultGranted: true,
      );
      expect(authorized.personalizedAdultEnergy, isTrue);
      expect(authorized.informationalFoodEstimate, isFalse,
        reason: 'Adult authorization is not a blanket photo consent.');
    }
  });

  test('signout, guest JWT and account loss deny both numeric capabilities',
      () {
    for (final signedIn in [false, true]) {
      for (final anonymous in [false, true]) {
        final result = StkNutritionCapabilityPolicy.resolve(
          declaredAge: 24,
          backendAdultGranted: true,
          backendInformationalGranted: true,
          approvedLegalRelease: true,
          approvedClinicalReview: true,
          currentPhotoConsent: true,
          signedIn: signedIn,
          isAnonymous: anonymous,
        );
        expect(result.personalizedAdultEnergy, signedIn && !anonymous);
        expect(result.informationalFoodEstimate, signedIn && !anonymous);
      }
    }
  });

  test('missing backend grant, absent release or consent never self-upgrades',
      () {
    final result = StkNutritionCapabilityPolicy.resolve(
      declaredAge: 18,
      backendAdultGranted: false,
      backendInformationalGranted: false,
      approvedLegalRelease: true,
      approvedClinicalReview: true,
      currentPhotoConsent: true,
    );
    expect(result.allows(StkNutritionCapability.foodDescription), isTrue);
    expect(result.allows(
      StkNutritionCapability.informationalFoodEstimate), isFalse);
    expect(result.allows(
      StkNutritionCapability.personalizedAdultEnergy), isFalse);
  });
}
