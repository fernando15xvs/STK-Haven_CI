import 'dart:io';

import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/onboarding/data/stk_mobile_legal_receipt_store.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late StkMobileLegalReceiptStore store;

  const approved = StkLegalDocumentSet(
    termsVersion: 'v1',
    termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    termsUrl: 'https://example.org/terms.txt',
    privacyVersion: 'v1',
    privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    privacyUrl: 'https://example.org/privacy.txt',
    approvedAndPublished: true,
  );

  StkLegalAcceptanceReceipt make(
    StkLegalSubjectType type,
    String id,
  ) => StkLegalAcceptanceReceipt.record(
    documents: approved,
    birthDate: DateTime(2001, 2, 3),
    now: DateTime.utc(2026, 11, 17),
    confirmedMinimumAge: true,
    acceptedTerms: true,
    privacyNoticeShown: true,
    subjectType: type,
    subjectId: id,
    source: 'legal_settings',
    locale: 'es-PE',
  )!;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('stk-account-receipt-');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('stk_account_receipts_test');
    store = StkMobileLegalReceiptStore(box);
  });

  tearDownAll(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test('registered user explicitly accepts, and only own UID may read', () async {
    final a = make(StkLegalSubjectType.authenticated, 'user-a');
    await store.saveAuthenticated(a, activeUserId: 'user-a');
    expect(store.readAuthenticated(
      documents: approved, activeUserId: 'user-a',
    )?.toJson(), a.toJson());
    expect(store.readAuthenticated(
      documents: approved, activeUserId: 'user-b',
    ), isNull);
    expect(store.readAuthenticated(
      documents: approved, activeUserId: null,
    ), isNull);
  });

  test('cannot save another account or a guest receipt as signed-in', () async {
    final a = make(StkLegalSubjectType.authenticated, 'user-a');
    await expectLater(
      store.saveAuthenticated(a, activeUserId: 'user-b'),
      throwsStateError,
    );
    await expectLater(
      store.saveAuthenticated(a, activeUserId: null),
      throwsStateError,
    );
    final guest = make(StkLegalSubjectType.guest,
        await store.getOrCreateGuestId());
    await expectLater(
      store.saveAuthenticated(guest, activeUserId: 'user-a'),
      throwsStateError,
    );
    expect(store.readAuthenticated(
      documents: approved, activeUserId: 'user-b',
    ), isNull);
  });

  test('guest acceptance is not silently transferred during sign in', () async {
    final id = await store.getOrCreateGuestId();
    final guest = make(StkLegalSubjectType.guest, id);
    await store.saveGuest(guest);
    expect(store.readGuest(
      documents: approved, guestId: id,
    ), isNotNull);
    expect(store.readAuthenticated(
      documents: approved, activeUserId: 'new-signed-in-user',
    ), isNull);
  });

  test('account-local deletion keeps the other account and guest intact', () async {
    final b = make(StkLegalSubjectType.authenticated, 'user-b');
    await store.saveAuthenticated(b, activeUserId: 'user-b');
    await expectLater(store.clearLocalReceipt(
      subjectType: StkLegalSubjectType.authenticated,
      subjectId: 'user-b',
      activeUserId: 'user-a',
    ), throwsStateError);
    expect(store.readAuthenticated(
      documents: approved, activeUserId: 'user-b',
    ), isNotNull);
    await store.clearLocalReceipt(
      subjectType: StkLegalSubjectType.authenticated,
      subjectId: 'user-b',
      activeUserId: 'user-b',
    );
    expect(store.readAuthenticated(
      documents: approved, activeUserId: 'user-b',
    ), isNull);
    expect(store.readAuthenticated(
      documents: approved, activeUserId: 'user-a',
    ), isNotNull);
  });

  test('invalid backup payload is denied, never promoted to verified', () async {
    await box.put('stk_legal_account_receipt_v1:user-c', {
      'subjectType': 'authenticated',
      'subjectId': 'user-d',
      'termsVersion': 'v1',
    });
    expect(store.readAuthenticated(
      documents: approved, activeUserId: 'user-c',
    ), isNull);
    expect(make(StkLegalSubjectType.authenticated, 'user-a').source,
        'legal_settings');
  });
}
