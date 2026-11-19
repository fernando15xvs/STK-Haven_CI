import 'package:core/features/onboarding/application/stk_age_eligibility.dart';
import 'package:core/features/nutrition/application/stk_nutrition_capability_policy.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An editable birthday is useful for age-appropriate UI but is NEVER proof
/// of adult nutrition access. Only the authenticated backend RPC can grant it.
enum NutritionAccessState {
  ageUnknown,
  minor,
  adultUnverified,
  adultVerified;

  bool get canViewNumericNutrition => this == NutritionAccessState.adultVerified;
  bool get isMinor => this == NutritionAccessState.minor;
}

/// Pure and deterministic for unit tests, offline behavior and safe defaults.
class NutritionAccessPolicy {
  const NutritionAccessPolicy._();

  static NutritionAccessState resolve({
    required int? declaredAge,
    required bool backendVerifiedAdult,
  }) {
    // Unknown age and implausible legacy dates never inherit an old grant.
    // An adult grant is useful only for a declared 18+ account.
    return switch (StkAgeEligibility.classifyYears(declaredAge)) {
      StkDeclaredAgeBand.unknownLegacy => NutritionAccessState.ageUnknown,
      StkDeclaredAgeBand.under15 ||
      StkDeclaredAgeBand.teen15To17 => NutritionAccessState.minor,
      StkDeclaredAgeBand.adult18PlusDeclared =>
        StkNutritionCapabilityPolicy.resolve(
          declaredAge: declaredAge,
          backendAdultGranted: backendVerifiedAdult,
        ).personalizedAdultEnergy
          ? NutritionAccessState.adultVerified
          : NutritionAccessState.adultUnverified,
    };
  }
}

/// Reacts to changes in the local profile; the bool is always supplied by
/// the fresh server RPC, never by birth date or identity.
final nutritionAccessStateProvider =
    Provider.family<NutritionAccessState, bool>((ref, backendVerifiedAdult) {
  final profile = ref.watch(userExperienceProfileProvider).value;
  return NutritionAccessPolicy.resolve(
    declaredAge: profile?.ageAt(DateTime.now()),
    backendVerifiedAdult: backendVerifiedAdult,
  );
});
