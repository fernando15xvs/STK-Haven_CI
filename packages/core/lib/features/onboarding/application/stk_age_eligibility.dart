/// Proposed STK Haven 15+ eligibility policy.
///
/// This is a locally evaluated, DECLARED age band, not identity verification.
/// Never use it to grant `adultVerified` or to authorize a privileged RPC.
enum StkDeclaredAgeBand {
  unknownLegacy,
  under15,
  teen15To17,
  adult18PlusDeclared,
}

class StkAgeEligibility {
  const StkAgeEligibility._();

  static const int minimumAge = 15;

  /// Day-only calculations are independent of the current clock time.
  /// On 29 February, the birthday is reached on 1 March in non-leap years.
  static int? ageOn(DateTime? birthDate, DateTime today) {
    if (birthDate == null || birthDate.year < 1900) return null;
    final dobDay = DateTime.utc(
      birthDate.year, birthDate.month, birthDate.day,
    );
    final todayDay = DateTime.utc(today.year, today.month, today.day);
    if (dobDay.isAfter(todayDay)) return null;
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age >= 0 ? age : null;
  }

  static StkDeclaredAgeBand classify({
    required DateTime? birthDate,
    required DateTime today,
  }) {
    final age = ageOn(birthDate, today);
    if (age == null) return StkDeclaredAgeBand.unknownLegacy;
    if (age < minimumAge) return StkDeclaredAgeBand.under15;
    if (age < 18) return StkDeclaredAgeBand.teen15To17;
    return StkDeclaredAgeBand.adult18PlusDeclared;
  }

  /// For NEW registrations only. Legacy/offline data must be migrated
  /// non-destructively instead of erasing an existing person's history.
  static bool canBeginNewAccount({
    required DateTime? birthDate,
    required DateTime today,
  }) {
    final band = classify(birthDate: birthDate, today: today);
    return band == StkDeclaredAgeBand.teen15To17 ||
        band == StkDeclaredAgeBand.adult18PlusDeclared;
  }
}

/// A feature matrix, NOT a token or proof of age. Server permissions
/// stay authoritative for personalized numeric nutrition.
class StkNutritionFeatureAccess {
  final bool canSeeEducationalGoals;
  final bool canRequestDescriptiveFoodVision;
  final bool canViewInformationalPhotoNumbers;
  final bool canViewPersonalizedAdultTargets;

  const StkNutritionFeatureAccess({
    required this.canSeeEducationalGoals,
    required this.canRequestDescriptiveFoodVision,
    required this.canViewInformationalPhotoNumbers,
    required this.canViewPersonalizedAdultTargets,
  });

  /// Fail closed for numeric values until the legal/clinical review approves
  /// adolescent photo estimates and a distinct server-side authorization is
  /// implemented. Current Food Vision backend must NOT be bypassed.
  static StkNutritionFeatureAccess resolve({
    required StkDeclaredAgeBand declaredAge,
    required bool termsCurrent,
    required bool isOnline,
    required bool photoProcessingConsented,
    required bool backendVerifiedAdult,
    required bool backendGrantFresh,
  }) {
    final eligible = declaredAge == StkDeclaredAgeBand.teen15To17 ||
        declaredAge == StkDeclaredAgeBand.adult18PlusDeclared;
    final canUse = eligible && termsCurrent;
    final verifiedAdult = canUse &&
        declaredAge == StkDeclaredAgeBand.adult18PlusDeclared &&
        isOnline &&
        backendVerifiedAdult &&
        backendGrantFresh;
    return StkNutritionFeatureAccess(
      canSeeEducationalGoals: canUse,
      canRequestDescriptiveFoodVision:
          canUse && isOnline && photoProcessingConsented,
      // Informational photo ranges for teens are a planned feature only,
      // blocked until the independent safety review and backend policy.
      canViewInformationalPhotoNumbers: verifiedAdult &&
          photoProcessingConsented,
      canViewPersonalizedAdultTargets: verifiedAdult,
    );
  }
}
