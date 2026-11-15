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
    // A declared minor never sees adult-only ranges even if an old grant
    // remains cached during the account transition.
    if (declaredAge != null && declaredAge < 18) {
      return NutritionAccessState.minor;
    }
    if (backendVerifiedAdult) {
      return NutritionAccessState.adultVerified;
    }
    if (declaredAge == null) {
      return NutritionAccessState.ageUnknown;
    }
    return NutritionAccessState.adultUnverified;
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
