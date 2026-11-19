import 'package:core/features/onboarding/application/stk_age_eligibility.dart';

/// Product capabilities, deliberately separate from an editable date of birth
/// and from a local legal acceptance receipt.
///
/// This is a defensive client projection of SERVER DECISIONS, not a grant
/// writer. The caller must obtain fresh backend answers for each identity.
/// No JWT user_metadata, profile flags, guest receipts or DOB may be treated
/// as a source of backendAdultGranted/backendInformationalGranted.
enum StkNutritionCapability {
  foodDescription,
  informationalFoodEstimate,
  personalizedAdultEnergy,
}

class StkNutritionCapabilityDecision {
  const StkNutritionCapabilityDecision({
    required this.ageBand,
    required this.foodDescription,
    required this.informationalFoodEstimate,
    required this.personalizedAdultEnergy,
  });

  final StkDeclaredAgeBand ageBand;

  /// Non-numeric identification and general educational text only.
  final bool foodDescription;

  /// Educational per-food estimates, NOT a daily budget or weight target.
  /// Deliberately disabled until a separate trusted backend decision AND
  /// legal/clinical/consent gates exist.
  final bool informationalFoodEstimate;

  /// Personalized adult calorie targets. Requires an existing server grant.
  final bool personalizedAdultEnergy;

  bool allows(StkNutritionCapability capability) => switch (capability) {
    StkNutritionCapability.foodDescription => foodDescription,
    StkNutritionCapability.informationalFoodEstimate =>
      informationalFoodEstimate,
    StkNutritionCapability.personalizedAdultEnergy =>
      personalizedAdultEnergy,
  };
}

class StkNutritionCapabilityPolicy {
  const StkNutritionCapabilityPolicy._();

  static StkNutritionCapabilityDecision resolve({
    required int? declaredAge,
    required bool backendAdultGranted,
    bool backendInformationalGranted = false,
    bool approvedLegalRelease = false,
    bool approvedClinicalReview = false,
    bool currentPhotoConsent = false,
    bool signedIn = true,
    bool isAnonymous = false,
  }) {
    final ageBand = StkAgeEligibility.classifyYears(declaredAge);
    final eligible = ageBand == StkDeclaredAgeBand.teen15To17 ||
        ageBand == StkDeclaredAgeBand.adult18PlusDeclared;
    final permanentSession = signedIn && !isAnonymous;

    return StkNutritionCapabilityDecision(
      ageBand: ageBand,
      // Existing descriptive Food Vision is intentionally not tied to
      // adult grants; contextual image-consent enforcement remains separate.
      foodDescription: eligible,
      informationalFoodEstimate: eligible &&
          permanentSession &&
          backendInformationalGranted &&
          approvedLegalRelease &&
          approvedClinicalReview &&
          currentPhotoConsent,
      personalizedAdultEnergy:
          ageBand == StkDeclaredAgeBand.adult18PlusDeclared &&
          permanentSession &&
          backendAdultGranted,
    );
  }
}
