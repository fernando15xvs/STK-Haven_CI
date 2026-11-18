import 'package:supabase_flutter/supabase_flutter.dart';

/// A result of checking the trusted backend, not proof of age by itself.
///
/// A failed network request must NEVER be rendered as "not verified":
/// it means the answer could not be obtained. Only [verified] can unlock
/// numeric nutrition, and callers must continue server checks on save.
enum NutritionAdultCheck {
  checking,
  verified,
  unverified,
  unavailable,
  signedOut;

  bool get allowsNumeric => this == NutritionAdultCheck.verified;
  bool get canRetry => this == NutritionAdultCheck.unavailable;
}

class NutritionAdultAccessService {
  final SupabaseClient client;

  const NutritionAdultAccessService(this.client);

  /// The signed-in user and their session are captured at the time of the
  /// request. A response for a previous account is never used for a new one.
  Future<NutritionAdultCheck> checkStatus() {
    final user = client.auth.currentUser;
    return queryStatus(
      userId: user?.id,
      isAnonymous: user?.isAnonymous ?? false,
      currentUserId: () => client.auth.currentUser?.id,
      fetch: () => client.rpc('stk_has_adult_nutrition_access'),
    );
  }

  /// Pure query boundary for unit tests and reconnect/session-race behavior.
  /// A false result is a real backend denial; a thrown, timed-out or
  /// malformed response is an unavailable check, with numeric access denied.
  static Future<NutritionAdultCheck> queryStatus({
    required String? userId,
    required bool isAnonymous,
    required String? Function() currentUserId,
    required Future<dynamic> Function() fetch,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (userId == null || userId.isEmpty || isAnonymous) {
      return NutritionAdultCheck.signedOut;
    }
    try {
      final response = await fetch().timeout(timeout);
      if (currentUserId() != userId) return NutritionAdultCheck.signedOut;
      if (response == true) return NutritionAdultCheck.verified;
      if (response == false) return NutritionAdultCheck.unverified;
      return NutritionAdultCheck.unavailable;
    } catch (_) {
      if (currentUserId() != userId) return NutritionAdultCheck.signedOut;
      return NutritionAdultCheck.unavailable;
    }
  }

  /// Backwards-compatible fail-closed guard used by saving, Food Vision
  /// and other existing callers. Do not grant access through an editable DOB.
  Future<bool> hasVerifiedAccess() async =>
      (await checkStatus()).allowsNumeric;
}
