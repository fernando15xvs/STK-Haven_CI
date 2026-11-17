import 'dart:io';

import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/onboarding/data/stk_mobile_legal_receipt_store.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late StkMobileLegalReceiptStore store;

  const documents = StkLegalDocumentSet(
    termsVersion: 'test-terms-v1',
    termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    termsUrl: 'https://example.org/terms.txt',
    privacyVersion: 'test-privacy-v1',
    privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    privacyUrl: 'https://example.org/privacy.txt',
    approvedAndPublished: true,
  );

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('stk-legal-receipt-');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('legal_receipts_test');
    store = StkMobileLegalReceiptStore(box);
  });

  tearDownAll(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test('guest ID remains stable across app sessions', () async {
    final id1 = await store.getOrCreateGuestId();
    final id2 = await StkMobileLegalReceiptStore(box).getOrCreateGuestId();
    expect(id1, id2);
    expect(id1, isNotEmpty);
  });

  test('acceptance survives local serialization for the same guest and version', () async {
    final id = await store.getOrCreateGuestId();
    final receipt = StkLegalAcceptanceReceipt.record(
      documents: documents,
      birthDate: DateTime(2005, 7, 1),
      now: DateTime.utc(2026, 11, 17),
      confirmedMinimumAge: true,
      acceptedTerms: true,
      privacyNoticeShown: true,
      subjectType: StkLegalSubjectType.guest,
      subjectId: id,
      locale: 'es-PE',
    )!;
    await store.saveGuest(receipt);
    final saved = StkMobileLegalReceiptStore(box).readGuest(
      documents: documents,
      guestId: id,
    );
    expect(saved, isNotNull);
    expect(saved!.toJson(), receipt.toJson());
    expect(store.readGuest(
      documents: documents,
      guestId: 'different-installation',
    ), isNull);
  });

  test('an identity-swapped receipt cannot overwrite local acceptance', () async {
    final foreign = StkLegalAcceptanceReceipt.record(
      documents: documents,
      birthDate: DateTime(2002, 5, 1),
      now: DateTime.utc(2026, 11, 17),
      confirmedMinimumAge: true,
      acceptedTerms: true,
      privacyNoticeShown: true,
      subjectType: StkLegalSubjectType.guest,
      subjectId: 'another-device',
      locale: 'es-PE',
    )!;
    await expectLater(
      store.saveGuest(foreign),
      throwsStateError,
    );
  });

  test('an updated legal version invalidates the old guest receipt', () async {
    final id = await store.getOrCreateGuestId();
    const updated = StkLegalDocumentSet(
      termsVersion: 'test-terms-v2',
      termsSha256: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      termsUrl: 'https://example.org/terms-v2.txt',
      privacyVersion: 'test-privacy-v1',
      privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      privacyUrl: 'https://example.org/privacy.txt',
      approvedAndPublished: true,
    );
    expect(store.readGuest(documents: updated, guestId: id), isNull);
  });
}
