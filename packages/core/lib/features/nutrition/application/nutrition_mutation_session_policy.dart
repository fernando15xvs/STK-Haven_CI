/// Scopes an in-flight LOCAL nutrition mutation to the same authenticated
/// session that started it. This is not a server grant or age verification.
///
/// Tokens are compared only in memory; never persist them in Hive, logs,
/// analytics, cache keys or diagnostics. Token refresh is treated as a new
/// scope: the user can retry the interrupted local action.
class NutritionMutationSessionPolicy {
  const NutritionMutationSessionPolicy._();

  static bool isCurrent({
    required String initialOwnerId,
    required String? initialAccessToken,
    required String currentOwnerId,
    required String? currentAccessToken,
  }) {
    if (initialOwnerId != currentOwnerId) return false;

    // Legacy guest-only local history is valid without a remote session.
    if (initialOwnerId == 'guest') {
      return initialAccessToken == null && currentAccessToken == null;
    }

    // Authenticated users must have an actual session; a missing token is
    // never equivalent to a trusted authenticated snapshot.
    if (initialAccessToken == null || initialAccessToken.isEmpty ||
        currentAccessToken == null || currentAccessToken.isEmpty) {
      return false;
    }
    return initialAccessToken == currentAccessToken;
  }
}
