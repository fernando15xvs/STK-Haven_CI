import 'stk_age_eligibility.dart';

/// Publication metadata must be supplied only after legal approval.
/// The draft markdown files in the repository are NOT publishable documents.
class StkLegalDocumentSet {
  const StkLegalDocumentSet({
    required this.termsVersion,
    required this.termsSha256,
    required this.termsUrl,
    required this.privacyVersion,
    required this.privacySha256,
    required this.privacyUrl,
    required this.approvedAndPublished,
  });

  final String termsVersion;
  final String termsSha256;
  final String termsUrl;
  final String privacyVersion;
  final String privacySha256;
  final String privacyUrl;
  final bool approvedAndPublished;

  static final RegExp _sha256 = RegExp(r'^[a-fA-F0-9]{64}$');

  bool get canCollectAcceptance {
    final termsUri = Uri.tryParse(termsUrl);
    final privacyUri = Uri.tryParse(privacyUrl);
    return approvedAndPublished &&
        termsVersion.trim().isNotEmpty &&
        privacyVersion.trim().isNotEmpty &&
        _sha256.hasMatch(termsSha256) &&
        _sha256.hasMatch(privacySha256) &&
        termsUri != null &&
        privacyUri != null &&
        termsUri.scheme == 'https' &&
        privacyUri.scheme == 'https' &&
        termsUri.host.isNotEmpty &&
        privacyUri.host.isNotEmpty;
  }
}

enum StkLegalSubjectType { guest, authenticated }

/// A locally stored audit receipt, NOT server-side proof of identity.
/// A backup containing this value must never create a privileged grant.
class StkLegalAcceptanceReceipt {
  const StkLegalAcceptanceReceipt._({
    required this.subjectType,
    required this.subjectId,
    required this.termsVersion,
    required this.termsSha256,
    required this.privacyVersion,
    required this.privacySha256,
    required this.acceptedAtUtc,
    required this.locale,
    required this.source,
  });

  final StkLegalSubjectType subjectType;
  final String subjectId;
  final String termsVersion;
  final String termsSha256;
  final String privacyVersion;
  final String privacySha256;
  final DateTime acceptedAtUtc;
  final String locale;
  final String source;

  /// A receipt may be recorded only for an eligible age, both mandatory
  /// checkboxes and a privacy notice actually shown to the person.
  static StkLegalAcceptanceReceipt? record({
    required StkLegalDocumentSet documents,
    required DateTime birthDate,
    required DateTime now,
    required bool confirmedMinimumAge,
    required bool acceptedTerms,
    required bool privacyNoticeShown,
    required StkLegalSubjectType subjectType,
    required String subjectId,
    required String locale,
    String source = 'onboarding',
  }) {
    if (!documents.canCollectAcceptance ||
        !confirmedMinimumAge ||
        !acceptedTerms ||
        !privacyNoticeShown ||
        !StkAgeEligibility.canBeginNewAccount(
          birthDate: birthDate,
          today: now,
        ) ||
        subjectId.trim().isEmpty ||
        locale.trim().isEmpty ||
        (source != 'onboarding' && source != 'legal_settings')) {
      return null;
    }
    return StkLegalAcceptanceReceipt._(
      subjectType: subjectType,
      subjectId: subjectId.trim(),
      termsVersion: documents.termsVersion,
      termsSha256: documents.termsSha256.toLowerCase(),
      privacyVersion: documents.privacyVersion,
      privacySha256: documents.privacySha256.toLowerCase(),
      acceptedAtUtc: now.toUtc(),
      locale: locale.trim(),
      source: source,
    );
  }

  /// Never reuse a guest receipt for another UID or another document version.
  bool isCurrentFor({
    required StkLegalDocumentSet documents,
    required StkLegalSubjectType subjectType,
    required String subjectId,
  }) {
    return documents.canCollectAcceptance &&
        subjectType == this.subjectType &&
        subjectId.isNotEmpty &&
        subjectId == this.subjectId &&
        termsVersion == documents.termsVersion &&
        termsSha256 == documents.termsSha256.toLowerCase() &&
        privacyVersion == documents.privacyVersion &&
        privacySha256 == documents.privacySha256.toLowerCase();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'subjectType': subjectType.name,
    'subjectId': subjectId,
    'termsVersion': termsVersion,
    'termsSha256': termsSha256,
    'privacyVersion': privacyVersion,
    'privacySha256': privacySha256,
    'acceptedAtUtc': acceptedAtUtc.toIso8601String(),
    'locale': locale,
    'source': source,
  };

  /// Parsing old or external backups is intentionally conservative. A
  /// decoded local receipt cannot authorize numeric nutrition or any RPC.
  static StkLegalAcceptanceReceipt? fromJson(Map<String, dynamic> json) {
    final kind = json['subjectType'];
    if (kind != StkLegalSubjectType.guest.name &&
        kind != StkLegalSubjectType.authenticated.name) {
      return null;
    }
    final subjectId = json['subjectId'];
    final termsVersion = json['termsVersion'];
    final termsHash = json['termsSha256'];
    final privacyVersion = json['privacyVersion'];
    final privacyHash = json['privacySha256'];
    final locale = json['locale'];
    final source = json['source'];
    final date = DateTime.tryParse(json['acceptedAtUtc']?.toString() ?? '');
    if (subjectId is! String || subjectId.trim().isEmpty ||
        termsVersion is! String || termsVersion.trim().isEmpty ||
        termsHash is! String || !StkLegalDocumentSet._sha256.hasMatch(termsHash) ||
        privacyVersion is! String || privacyVersion.trim().isEmpty ||
        privacyHash is! String || !StkLegalDocumentSet._sha256.hasMatch(privacyHash) ||
        locale is! String || locale.trim().isEmpty ||
        (source != 'onboarding' && source != 'legal_settings') ||
        date == null ||
        !date.isUtc) {
      return null;
    }
    return StkLegalAcceptanceReceipt._(
      subjectType: kind == StkLegalSubjectType.guest.name
          ? StkLegalSubjectType.guest
          : StkLegalSubjectType.authenticated,
      subjectId: subjectId,
      termsVersion: termsVersion,
      termsSha256: termsHash.toLowerCase(),
      privacyVersion: privacyVersion,
      privacySha256: privacyHash.toLowerCase(),
      acceptedAtUtc: date,
      locale: locale,
      source: source as String,
    );
  }
}
