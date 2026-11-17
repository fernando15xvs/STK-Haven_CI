import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';

/// No on-device legal gate can be activated until approved documents are
/// published and their actual content SHA-256 hashes are configured.
/// Draft documents from docs/legal are not shipped as binding policies.
class StkMobileLegalConfig {
  const StkMobileLegalConfig._();

  static const bool enabled = bool.fromEnvironment(
    'STK_ENABLE_15_PLUS_ONBOARDING',
    defaultValue: false,
  );

  static const StkLegalDocumentSet documents = StkLegalDocumentSet(
    termsVersion: String.fromEnvironment('STK_TERMS_VERSION'),
    termsSha256: String.fromEnvironment('STK_TERMS_SHA256'),
    termsUrl: String.fromEnvironment('STK_TERMS_HTTPS_URL'),
    privacyVersion: String.fromEnvironment('STK_PRIVACY_VERSION'),
    privacySha256: String.fromEnvironment('STK_PRIVACY_SHA256'),
    privacyUrl: String.fromEnvironment('STK_PRIVACY_HTTPS_URL'),
    approvedAndPublished: bool.fromEnvironment(
      'STK_LEGAL_APPROVED_AND_PUBLISHED',
      defaultValue: false,
    ),
  );
}
