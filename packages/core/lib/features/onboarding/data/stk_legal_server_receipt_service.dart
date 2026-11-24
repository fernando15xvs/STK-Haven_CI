import 'package:core/features/onboarding/application/stk_age_eligibility.dart';
import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:supabase/supabase.dart';

/// Server-stamped proof that a *signed-in account* accepted the exact
/// published T&C and privacy versions. This does not prove identity or age,
/// and cannot confer any nutrition grant. Guests remain local only.
class StkLegalServerReceiptService {
  const StkLegalServerReceiptService(this.client);

  final SupabaseClient client;

  /// A locally packaged approval is NOT enough: the backend must publish
  /// exactly these URLs, versions and SHA-256 hashes before acceptance.
  static bool matchesPublishedRelease(
    Object? response,
    StkLegalDocumentSet documents,
  ) {
    if (!documents.canCollectAcceptance || response is! Map) return false;
    return response['termsVersion'] == documents.termsVersion &&
        response['termsSha256'] == documents.termsSha256.toLowerCase() &&
        response['termsUrl'] == documents.termsUrl &&
        response['privacyVersion'] == documents.privacyVersion &&
        response['privacySha256'] == documents.privacySha256.toLowerCase() &&
        response['privacyUrl'] == documents.privacyUrl;
  }

  Future<bool> recordAcceptance({
    required StkLegalAcceptanceReceipt receipt,
    required StkLegalDocumentSet documents,
    required DateTime declaredBirthDate,
  }) async {
    final user = client.auth.currentUser;
    final uid = user?.id;
    final token = client.auth.currentSession?.accessToken;
    if (uid == null || uid.isEmpty || user!.isAnonymous ||
        token == null || token.isEmpty ||
        !receipt.isCurrentFor(
          documents: documents,
          subjectType: StkLegalSubjectType.authenticated,
          subjectId: uid,
        )) return false;

    final band = StkAgeEligibility.classify(
      birthDate: declaredBirthDate,
      today: DateTime.now(),
    );
    final ageBand = switch (band) {
      StkDeclaredAgeBand.teen15To17 => '15_17',
      StkDeclaredAgeBand.adult18PlusDeclared => '18_plus',
      _ => null,
    };
    if (ageBand == null) return false;
    bool sameSession() => client.auth.currentUser?.id == uid &&
        client.auth.currentUser?.isAnonymous == false &&
        client.auth.currentSession?.accessToken == token;
    try {
      final published = await client.rpc('stk_get_current_legal_release')
          .timeout(const Duration(seconds: 12));
      if (!sameSession() || !matchesPublishedRelease(published, documents)) {
        return false;
      }
      // The RPC derives the owner from auth.uid and stamps server time.
      // It receives neither a user_id nor a trusted-age boolean.
      final serverId = await client.rpc('stk_record_legal_acceptance', params: {
        'p_terms_version': receipt.termsVersion,
        'p_terms_sha256': receipt.termsSha256,
        'p_privacy_version': receipt.privacyVersion,
        'p_privacy_sha256': receipt.privacySha256,
        'p_declared_age_band': ageBand,
      }).timeout(const Duration(seconds: 12));
      return sameSession() && serverId is String && serverId.isNotEmpty;
    } catch (_) {
      // Absent migration, timeout, legal mismatch and revoked session
      // fail closed. A local Hive receipt is NEVER a remote replacement.
      return false;
    }
  }

  Future<bool> revokeCurrentAcceptance() async {
    final user = client.auth.currentUser;
    final uid = user?.id;
    final token = client.auth.currentSession?.accessToken;
    if (uid == null || user!.isAnonymous || token == null || token.isEmpty) {
      return false;
    }
    try {
      final result = await client.rpc('stk_revoke_legal_acceptance')
          .timeout(const Duration(seconds: 12));
      return result == true &&
          client.auth.currentUser?.id == uid &&
          client.auth.currentSession?.accessToken == token;
    } catch (_) {
      return false;
    }
  }
}
