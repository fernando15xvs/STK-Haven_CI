import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:core/features/onboarding/data/stk_legal_server_receipt_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const docs = StkLegalDocumentSet(
    termsVersion: 'release-1',
    termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    termsUrl: 'https://example.org/legal/terms',
    privacyVersion: 'privacy-1',
    privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    privacyUrl: 'https://example.org/legal/privacy',
    approvedAndPublished: true,
  );

  final matching = {
    'termsVersion': docs.termsVersion,
    'termsSha256': docs.termsSha256,
    'termsUrl': docs.termsUrl,
    'privacyVersion': docs.privacyVersion,
    'privacySha256': docs.privacySha256,
    'privacyUrl': docs.privacyUrl,
  };

  test('current published policy requires all six exact metadata values', () {
    expect(StkLegalServerReceiptService.matchesPublishedRelease(matching,docs),
        isTrue);
    for (final key in matching.keys) {
      final tampered = Map<String, dynamic>.from(matching);
      tampered[key] = 'changed';
      expect(StkLegalServerReceiptService.matchesPublishedRelease(tampered,docs),
          isFalse, reason: 'Mismatched policy field $key');
    }
  });

  test('unpublished and malformed server replies cannot establish acceptance',
      () {
    for (final reply in <Object?>[null, true, 'approved', [], {}, {'termsVersion':'release-1'}]) {
      expect(StkLegalServerReceiptService.matchesPublishedRelease(reply,docs),
          isFalse);
    }
    const drafts = StkLegalDocumentSet(
      termsVersion: 'release-1',
      termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      termsUrl: 'https://example.org/legal/terms',
      privacyVersion: 'privacy-1',
      privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      privacyUrl: 'https://example.org/legal/privacy',
      approvedAndPublished: false,
    );
    expect(StkLegalServerReceiptService.matchesPublishedRelease(matching,drafts),
        isFalse);
  });
}
