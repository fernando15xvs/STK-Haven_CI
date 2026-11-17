import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:hive/hive.dart';

/// Optional, revocable, per-identity preferences. This store is NOT a server
/// authorization service and is never used to grant numeric nutrition access.
enum StkOptionalConsentPurpose {
  foodVisionAi,
  sensitiveHealthCloudSync,
  productCommunications,
}

class StkMobileOptionalConsentStore {
  StkMobileOptionalConsentStore(this._box);

  static const _prefix = 'stk_consent_v1:';
  final Box<dynamic> _box;

  /// A missing, malformed, outdated or revoked record is always denied.
  bool isGranted({
    required StkOptionalConsentPurpose purpose,
    required StkLegalDocumentSet documents,
    required StkLegalSubjectType subjectType,
    required String subjectId,
    required String? activeUserId,
  }) {
    if (!documents.canCollectAcceptance ||
        !_validIdentity(subjectType, subjectId, activeUserId)) {
      return false;
    }
    final raw = _box.get(_key(purpose, subjectType, subjectId));
    if (raw is! Map) return false;
    try {
      final map = Map<String, dynamic>.from(raw);
      return map['granted'] == true &&
          map['purpose'] == purpose.name &&
          map['subjectType'] == subjectType.name &&
          map['subjectId'] == subjectId &&
          map['privacyVersion'] == documents.privacyVersion &&
          map['privacySha256'] ==
              documents.privacySha256.toLowerCase() &&
          DateTime.tryParse(map['updatedAtUtc']?.toString() ?? '')?.isUtc ==
              true;
    } catch (_) {
      return false;
    }
  }

  /// Only the person presently authenticated may grant their own permission.
  /// Revoke works even if the document has changed or is unpublished.
  Future<void> setGranted({
    required StkOptionalConsentPurpose purpose,
    required StkLegalDocumentSet documents,
    required StkLegalSubjectType subjectType,
    required String subjectId,
    required String? activeUserId,
    required bool granted,
    required StkLegalAcceptanceReceipt? legalReceipt,
    required DateTime now,
  }) async {
    if (!_validIdentity(subjectType, subjectId, activeUserId)) {
      throw StateError('No se puede cambiar el permiso de otra cuenta.');
    }
    if (granted &&
        (!documents.canCollectAcceptance ||
         legalReceipt == null ||
         !legalReceipt.isCurrentFor(
           documents: documents,
           subjectType: subjectType,
           subjectId: subjectId,
         ))) {
      throw StateError('Debes aceptar las condiciones vigentes.');
    }
    await _box.put(_key(purpose, subjectType, subjectId), {
      'purpose': purpose.name,
      'subjectType': subjectType.name,
      'subjectId': subjectId,
      'privacyVersion': documents.privacyVersion,
      'privacySha256': documents.privacySha256.toLowerCase(),
      'granted': granted,
      'updatedAtUtc': now.toUtc().toIso8601String(),
    });
  }

  /// Independent revocation of all nonessential local consents.
  Future<void> revokeAll({
    required StkLegalDocumentSet documents,
    required StkLegalSubjectType subjectType,
    required String subjectId,
    required String? activeUserId,
    required DateTime now,
  }) async {
    for (final purpose in StkOptionalConsentPurpose.values) {
      await setGranted(
        purpose: purpose,
        documents: documents,
        subjectType: subjectType,
        subjectId: subjectId,
        activeUserId: activeUserId,
        granted: false,
        legalReceipt: null,
        now: now,
      );
    }
  }

  /// The caller supplies a fresh auth UID from Supabase Auth currentUser,
  /// never a user-editable profile or JWT user_metadata field.
  bool _validIdentity(
    StkLegalSubjectType type,
    String id,
    String? activeUserId,
  ) {
    if (id.trim().isEmpty) return false;
    if (type == StkLegalSubjectType.authenticated) {
      return activeUserId != null &&
          activeUserId.isNotEmpty &&
          activeUserId == id;
    }
    return activeUserId == null;
  }

  String _key(
    StkOptionalConsentPurpose purpose,
    StkLegalSubjectType type,
    String id,
  ) => '$_prefix${type.name}:${Uri.encodeComponent(id)}:${purpose.name}';
}
