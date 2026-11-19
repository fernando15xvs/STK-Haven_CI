import 'package:supabase_flutter/supabase_flutter.dart';
import 'stk_nutrition_server_capabilities.dart';

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
      sessionToken: client.auth.currentSession?.accessToken,
      currentSessionToken: () => client.auth.currentSession?.accessToken,
      fetch: _fetchServerAdultCapability,
    );
  }

  /// Prefer the new independently reviewed capability when that migration
  /// exists. If a pre-migration backend has no such RPC, preserve the older
  /// server-controlled grant. A denial, revoked grant, malformed response,
  /// timeout or permission error must NEVER fall through to the legacy RPC.
  Future<dynamic> _fetchServerAdultCapability() async {
    try {
      final result = await client.rpc('stk_get_nutrition_capabilities');
      final parsed = StkNutritionServerCapabilities.parse(result);
      return parsed?.personalizedAdultEnergy;
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202' || error.code == '42883') {
        return client.rpc('stk_has_adult_nutrition_access');
      }
      rethrow;
    }
  }

  /// Pure query boundary for unit tests and reconnect/session-race behavior.
  /// A false result is a real backend denial; a thrown, timed-out or
  /// malformed response is an unavailable check, with numeric access denied.
  static Future<NutritionAdultCheck> queryStatus({
    required String? userId,
    required bool isAnonymous,
    required String? Function() currentUserId,
    // An identical user ID can log out and back in under a different session.
    // Keep this optional for pure callers; checkStatus always supplies both.
    String? sessionToken,
    String? Function()? currentSessionToken,
    required Future<dynamic> Function() fetch,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (userId == null || userId.isEmpty || isAnonymous ||
        (currentSessionToken != null &&
            (sessionToken == null || sessionToken.isEmpty))) {
      return NutritionAdultCheck.signedOut;
    }
    bool isOriginalSession() =>
        currentUserId() == userId &&
        (currentSessionToken == null ||
            currentSessionToken() == sessionToken);
    if (!isOriginalSession()) return NutritionAdultCheck.signedOut;
    try {
      final response = await fetch().timeout(timeout);
      if (!isOriginalSession()) return NutritionAdultCheck.signedOut;
      if (response == true) return NutritionAdultCheck.verified;
      if (response == false) return NutritionAdultCheck.unverified;
      return NutritionAdultCheck.unavailable;
    } catch (_) {
      if (!isOriginalSession()) return NutritionAdultCheck.signedOut;
      return NutritionAdultCheck.unavailable;
    }
  }

  /// Backwards-compatible fail-closed guard used by saving, Food Vision
  /// and other existing callers. Do not grant access through an editable DOB.
  Future<bool> hasVerifiedAccess() async =>
      (await checkStatus()).allowsNumeric;
}
