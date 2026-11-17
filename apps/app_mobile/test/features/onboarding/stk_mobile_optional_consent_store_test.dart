import 'dart:io';

import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/onboarding/data/stk_mobile_optional_consent_store.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  late Box<dynamic> box;
  late StkMobileOptionalConsentStore store;
  const documents = StkLegalDocumentSet(
    termsVersion: 'terms1',
    termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    termsUrl: 'https://example.org/terms',
    privacyVersion: 'privacy1',
    privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    privacyUrl: 'https://example.org/privacy',
    approvedAndPublished: true,
  );

  StkLegalAcceptanceReceipt receipt(String uid) =>
      StkLegalAcceptanceReceipt.record(
        documents: documents,
        birthDate: DateTime(2001, 1, 1),
        now: DateTime.utc(2026, 11, 17),
        confirmedMinimumAge: true,
        acceptedTerms: true,
        privacyNoticeShown: true,
        subjectType: StkLegalSubjectType.authenticated,
        subjectId: uid,
        locale: 'es-PE',
        source: 'legal_settings',
      )!;

  Future<void> set(
    String subject,
    bool value, {
    String? activeUserId,
    StkLegalDocumentSet docs = documents,
    StkLegalAcceptanceReceipt? accepted,
    StkOptionalConsentPurpose purpose = StkOptionalConsentPurpose.foodVisionAi,
  }) => store.setGranted(
    purpose: purpose,
    documents: docs,
    subjectType: StkLegalSubjectType.authenticated,
    subjectId: subject,
    activeUserId: activeUserId ?? subject,
    granted: value,
    legalReceipt: accepted,
    now: DateTime.utc(2026, 11, 17, 19),
  );

  bool granted(
    String user, {
    StkLegalDocumentSet docs = documents,
    StkOptionalConsentPurpose purpose = StkOptionalConsentPurpose.foodVisionAi,
  }) => store.isGranted(
    purpose: purpose,
    documents: docs,
    subjectType: StkLegalSubjectType.authenticated,
    subjectId: user,
    activeUserId: user,
  );

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('stk-consent-');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('consent_test');
    store = StkMobileOptionalConsentStore(box);
  });

  tearDownAll(() async {
    await box.close();
    await dir.delete(recursive: true);
  });

  test('no opt-in is granted by default, including to restored accounts', () {
    for (final purpose in StkOptionalConsentPurpose.values) {
      expect(granted('uid-a', purpose: purpose), isFalse);
      expect(granted('uid-b', purpose: purpose), isFalse);
    }
  });

  test('cannot accept optional consent without current legal receipt', () async {
    await expectLater(set('uid-a', true), throwsStateError);
    await expectLater(set('uid-a', true, accepted: receipt('uid-b')),
        throwsStateError);
    await expectLater(
      set('uid-a', true, activeUserId: 'uid-b', accepted: receipt('uid-a')),
      throwsStateError,
    );
    expect(granted('uid-a'), isFalse);
  });

  test('grant is scoped to a user and a single purpose', () async {
    await set('uid-a', true, accepted: receipt('uid-a'));
    expect(granted('uid-a'), isTrue);
    expect(granted('uid-b'), isFalse);
    expect(granted('uid-a',
        purpose: StkOptionalConsentPurpose.sensitiveHealthCloudSync),
        isFalse);
    expect(granted('uid-a',
        purpose: StkOptionalConsentPurpose.productCommunications),
        isFalse);
    await set('uid-b', true, accepted: receipt('uid-b'));
    expect(granted('uid-b'), isTrue);
  });

  test('a privacy version update invalidates previous permission', () async {
    const updated = StkLegalDocumentSet(
      termsVersion: 'terms1',
      termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      termsUrl: 'https://example.org/terms',
      privacyVersion: 'privacy2',
      privacySha256: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      privacyUrl: 'https://example.org/privacy-v2',
      approvedAndPublished: true,
    );
    expect(granted('uid-a', docs: updated), isFalse);
    await expectLater(
      set('uid-a', true, docs: updated, accepted: receipt('uid-a')),
      throwsStateError,
    );
  });

  test('individual revocation and all-consent revocation are durable', () async {
    await set('uid-a', false);
    expect(granted('uid-a'), isFalse);
    expect(granted('uid-b'), isTrue);
    await set('uid-b', true,
      purpose: StkOptionalConsentPurpose.sensitiveHealthCloudSync,
      accepted: receipt('uid-b'));
    await store.revokeAll(
      documents: documents,
      subjectType: StkLegalSubjectType.authenticated,
      subjectId: 'uid-b',
      activeUserId: 'uid-b',
      now: DateTime.utc(2026, 11, 17, 20),
    );
    final restoredStore = StkMobileOptionalConsentStore(box);
    for (final purpose in StkOptionalConsentPurpose.values) {
      expect(restoredStore.isGranted(
        purpose: purpose, documents: documents,
        subjectType: StkLegalSubjectType.authenticated,
        subjectId: 'uid-b', activeUserId: 'uid-b'), isFalse);
    }
  });

  test('malformed backups and guest-to-user reuse fail closed', () async {
    await box.put('stk_consent_v1:authenticated:uid-c:foodVisionAi',
        <String, dynamic>{'granted': true, 'subjectId': 'uid-b'});
    expect(granted('uid-c'), isFalse);
    expect(store.isGranted(
      purpose: StkOptionalConsentPurpose.foodVisionAi,
      documents: documents,
      subjectType: StkLegalSubjectType.guest,
      subjectId: 'guest-1',
      activeUserId: 'uid-b',
    ), isFalse);
  });

  test('documents unavailable never grant but existing permissions revoke', () async {
    const draft = StkLegalDocumentSet(
      termsVersion: 'draft',
      termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      termsUrl: 'https://example.org/terms',
      privacyVersion: 'draft',
      privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      privacyUrl: 'https://example.org/privacy',
      approvedAndPublished: false,
    );
    expect(granted('uid-b', docs: draft), isFalse);
    await expectLater(
      set('uid-b', true, docs: draft, accepted: receipt('uid-b')),
      throwsStateError,
    );
    await set('uid-a', false, docs: draft);
    expect(granted('uid-a'), isFalse);
  });
}
