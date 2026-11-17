import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const approvedDocuments = StkLegalDocumentSet(
    termsVersion: '2026-11-17.1',
    termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    termsUrl: 'https://example.org/terms/2026-11-17',
    privacyVersion: '2026-11-17.1',
    privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    privacyUrl: 'https://example.org/privacy/2026-11-17',
    approvedAndPublished: true,
  );
  const draftDocuments = StkLegalDocumentSet(
    termsVersion: 'draft',
    termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    termsUrl: 'https://example.org/terms',
    privacyVersion: 'draft',
    privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    privacyUrl: 'https://example.org/privacy',
    approvedAndPublished: false,
  );

  StkLegalAcceptanceReceipt? attempt({
    StkLegalDocumentSet docs = approvedDocuments,
    DateTime? birthDate,
    bool confirmedAge = true,
    bool termsChecked = true,
    bool privacyShown = true,
    String subject = 'guest-device-1',
    StkLegalSubjectType kind = StkLegalSubjectType.guest,
  }) => StkLegalAcceptanceReceipt.record(
    documents: docs,
    birthDate: birthDate ?? DateTime(2008, 5, 12),
    now: DateTime.utc(2026, 11, 17, 12),
    confirmedMinimumAge: confirmedAge,
    acceptedTerms: termsChecked,
    privacyNoticeShown: privacyShown,
    subjectType: kind,
    subjectId: subject,
    locale: 'es-PE',
  );

  test('repo markdown drafts cannot create a legal acceptance receipt', () {
    expect(draftDocuments.canCollectAcceptance, isFalse);
    expect(attempt(docs: draftDocuments), isNull);
    expect(approvedDocuments.canCollectAcceptance, isTrue);
  });

  test('both mandatory checks and a visible privacy notice are required', () {
    expect(attempt(confirmedAge: false), isNull);
    expect(attempt(termsChecked: false), isNull);
    expect(attempt(privacyShown: false), isNull);
    expect(attempt(subject: '  '), isNull);
  });

  test('under 15 cannot accept; exact 15th birthday is allowed', () {
    expect(attempt(birthDate: DateTime(2011, 11, 18)), isNull);
    expect(attempt(birthDate: DateTime(2011, 11, 17)), isNotNull);
    expect(attempt(birthDate: DateTime(2026, 11, 18)), isNull);
  });

  test('only HTTPS approved and hashed documents are eligible', () {
    const insecure = StkLegalDocumentSet(
      termsVersion: 'v1',
      termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      termsUrl: 'http://example.org/terms',
      privacyVersion: 'v1',
      privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      privacyUrl: 'https://example.org/privacy',
      approvedAndPublished: true,
    );
    const noHash = StkLegalDocumentSet(
      termsVersion: 'v1',
      termsSha256: 'not-a-real-hash',
      termsUrl: 'https://example.org/terms',
      privacyVersion: 'v1',
      privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      privacyUrl: 'https://example.org/privacy',
      approvedAndPublished: true,
    );
    expect(attempt(docs: insecure), isNull);
    expect(attempt(docs: noHash), isNull);
  });

  test('versioned receipt is immutable by serialization and bound to identity', () {
    final guest = attempt()!;
    expect(guest.source, 'onboarding');
    expect(guest.acceptedAtUtc.isUtc, isTrue);
    final restored = StkLegalAcceptanceReceipt.fromJson(guest.toJson())!;
    expect(restored.toJson(), guest.toJson());
    expect(restored.isCurrentFor(
      documents: approvedDocuments,
      subjectType: StkLegalSubjectType.guest,
      subjectId: 'guest-device-1',
    ), isTrue);
    expect(restored.isCurrentFor(
      documents: approvedDocuments,
      subjectType: StkLegalSubjectType.authenticated,
      subjectId: 'guest-device-1',
    ), isFalse);
    expect(restored.isCurrentFor(
      documents: approvedDocuments,
      subjectType: StkLegalSubjectType.guest,
      subjectId: 'another-installation',
    ), isFalse);
    // Guest acceptance is never silently transferred to a signed-in UID.
    expect(restored.isCurrentFor(
      documents: approvedDocuments,
      subjectType: StkLegalSubjectType.authenticated,
      subjectId: 'user-1',
    ), isFalse);
  });

  test('updated terms or privacy invalidate existing receipts', () {
    final receipt = attempt()!;
    const changedPrivacy = StkLegalDocumentSet(
      termsVersion: '2026-11-17.1',
      termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      termsUrl: 'https://example.org/terms/2026-11-17',
      privacyVersion: '2026-12-01.1',
      privacySha256: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      privacyUrl: 'https://example.org/privacy/2026-12-01',
      approvedAndPublished: true,
    );
    expect(receipt.isCurrentFor(
      documents: changedPrivacy,
      subjectType: StkLegalSubjectType.guest,
      subjectId: 'guest-device-1',
    ), isFalse);
  });

  test('untrusted backup fields fail closed when malformed', () {
    final good = attempt()!.toJson();
    expect(StkLegalAcceptanceReceipt.fromJson(
      <String, dynamic>{...good, 'subjectType': 'admin'},
    ), isNull);
    expect(StkLegalAcceptanceReceipt.fromJson(
      <String, dynamic>{...good, 'termsSha256': 'missing'},
    ), isNull);
    expect(StkLegalAcceptanceReceipt.fromJson(
      <String, dynamic>{...good, 'acceptedAtUtc': 'not-a-date'},
    ), isNull);
    expect(StkLegalAcceptanceReceipt.fromJson(
      <String, dynamic>{...good, 'source': 'magic-link'},
    ), isNull);
    expect(StkLegalAcceptanceReceipt.fromJson(<String, dynamic>{}), isNull);
  });
}
