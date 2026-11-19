import 'dart:async';

import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/onboarding/presentation/widgets/stk_legal_acceptance_panel.dart';

void main() {
  const approved = StkLegalDocumentSet(
    termsVersion: 'test-v1',
    termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    termsUrl: 'https://example.org/terms',
    privacyVersion: 'test-v1',
    privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    privacyUrl: 'https://example.org/privacy',
    approvedAndPublished: true,
  );
  const draft = StkLegalDocumentSet(
    termsVersion: 'draft',
    termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    termsUrl: 'https://example.org/terms',
    privacyVersion: 'draft',
    privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    privacyUrl: 'https://example.org/privacy',
    approvedAndPublished: false,
  );

  Widget page({
    StkLegalDocumentSet docs = approved,
    DateTime? birthday,
    String subjectId = 'guest-test-installation',
    void Function(StkLegalAcceptanceReceipt)? onAccepted,
    VoidCallback? onDecline,
    Future<bool> Function()? onTermsViewed,
    Future<bool> Function()? onPrivacyViewed,
  }) => MaterialApp(
    home: Scaffold(
      body: StkLegalAcceptancePanel(
        today: DateTime(2026, 11, 17),
        birthDate: birthday ?? DateTime(2006, 2, 20),
        documents: docs,
        subjectType: StkLegalSubjectType.guest,
        subjectId: subjectId,
        locale: 'es-PE',
        onViewTerms: onTermsViewed ?? () async => true,
        onViewPrivacy: onPrivacyViewed ?? () async => true,
        onAccepted: onAccepted ?? (_) {},
        onDecline: onDecline ?? () {},
      ),
    ),
  );

  testWidgets('both checks are initially unchecked and only then enable CTA',
      (tester) async {
    StkLegalAcceptanceReceipt? recorded;
    await tester.pumpWidget(page(onAccepted: (value) => recorded = value));
    final primary = find.byKey(const ValueKey('stk_legal_continue'));
    FilledButton button() => tester.widget<FilledButton>(primary);
    expect(button().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('stk_confirm_15_plus')));
    await tester.pump();
    expect(button().onPressed, isNull);

    final terms = find.byKey(const ValueKey('stk_terms_link'));
    final privacy = find.byKey(const ValueKey('stk_privacy_link'));
    await tester.tap(terms);
    await tester.pumpAndSettle();
    expect(button().onPressed, isNull);
    await tester.tap(privacy);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stk_accept_terms')));
    await tester.pump();
    expect(button().onPressed, isNotNull);

    await tester.ensureVisible(primary);
    await tester.tap(primary);
    await tester.pump();
    expect(recorded, isNotNull);
    expect(recorded?.termsVersion, 'test-v1');
    expect(recorded?.subjectId, 'guest-test-installation');
  });

  testWidgets('back or failed verification cannot produce legal acceptance',
      (tester) async {
    StkLegalAcceptanceReceipt? receipt;
    await tester.pumpWidget(page(
      onAccepted: (value) => receipt = value,
      onTermsViewed: () async => false,
      onPrivacyViewed: () async => true,
    ));
    await tester.tap(find.byKey(const ValueKey('stk_terms_link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stk_privacy_link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stk_confirm_15_plus')));
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('stk_accept_terms')),
    ).onChanged, isNull);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('stk_legal_continue')),
    ).onPressed, isNull);
    expect(receipt, isNull);
  });

  testWidgets('a draft cannot be accepted or presented as published',
      (tester) async {
    var submitted = false;
    await tester.pumpWidget(page(
      docs: draft,
      onAccepted: (_) => submitted = true,
    ));
    expect(find.byKey(const ValueKey('stk_legal_unpublished')),
      findsOneWidget);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('stk_legal_continue')),
    ).onPressed, isNull);
    expect(tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('stk_accept_terms')),
    ).onChanged, isNull);
    expect(submitted, isFalse);
  });

  testWidgets('under 15 cannot complete the step; declining makes no receipt',
      (tester) async {
    var accepted = false;
    var declined = 0;
    await tester.pumpWidget(page(
      birthday: DateTime(2011, 11, 18),
      onAccepted: (_) => accepted = true,
      onDecline: () => declined++,
    ));
    expect(find.byKey(const ValueKey('stk_legal_age_error')),
      findsOneWidget);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('stk_legal_continue')),
    ).onPressed, isNull);
    final decline = find.byKey(const ValueKey('stk_legal_decline'));
    // ListView builds children lazily. ensureVisible requires an element
    // already mounted, but this footer can begin outside the viewport.
    await tester.scrollUntilVisible(
      decline, 160, scrollable: find.byType(Scrollable).first,
    );
    expect(decline, findsOneWidget);
    await tester.tap(decline);
    await tester.pump();
    expect(declined, 1);
    expect(accepted, isFalse);
  });


  testWidgets('editing birth date resets both confirmations, even within 15+',
      (tester) async {
    var accepted = 0;
    await tester.pumpWidget(page(
      birthday: DateTime(2006, 2, 20),
      onAccepted: (_) => accepted++,
    ));
    await tester.tap(find.byKey(const ValueKey('stk_terms_link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stk_privacy_link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stk_confirm_15_plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stk_accept_terms')));
    await tester.pump();
    final submit = find.byKey(const ValueKey('stk_legal_continue'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.pumpWidget(page(
      birthday: DateTime(2010, 7, 5),
      onAccepted: (_) => accepted++,
    ));
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('stk_confirm_15_plus')),
    ).value, isFalse);
    expect(tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('stk_accept_terms')),
    ).value, isFalse);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(accepted, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late old document callback cannot approve replaced document',
      (tester) async {
    final pending = Completer<bool>();
    var accepted = false;
    await tester.pumpWidget(page(
      onTermsViewed: () => pending.future,
      onAccepted: (_) => accepted = true,
    ));
    await tester.tap(find.byKey(const ValueKey('stk_terms_link')));
    await tester.pump();

    // Same version and SHA but a changed publication URL must invalidate
    // both a prior review and any in-flight result.
    const moved = StkLegalDocumentSet(
      termsVersion: 'test-v1',
      termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      termsUrl: 'https://example.org/new-terms',
      privacyVersion: 'test-v1',
      privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      privacyUrl: 'https://example.org/privacy',
      approvedAndPublished: true,
    );
    await tester.pumpWidget(page(docs: moved,
      onAccepted: (_) => accepted = true,
    ));
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stk_legal_documents_reviewed')),
        findsNothing);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('stk_legal_continue')),
    ).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('stk_terms_link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stk_privacy_link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stk_confirm_15_plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stk_accept_terms')));
    await tester.pump();
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('stk_legal_continue')),
    ).onPressed, isNotNull);
    expect(accepted, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing guest identity invalidates the reviewed consent',
      (tester) async {
    await tester.pumpWidget(page());
    await tester.tap(find.byKey(const ValueKey('stk_terms_link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stk_privacy_link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stk_confirm_15_plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stk_accept_terms')));
    await tester.pump();
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('stk_legal_continue')),
    ).onPressed, isNotNull);

    await tester.pumpWidget(page(subjectId: 'another-installation'));
    await tester.pump();
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('stk_legal_continue')),
    ).onPressed, isNull);
    expect(tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('stk_accept_terms')),
    ).value, isFalse);
  });

  testWidgets('small screens and 200 percent accessibility text can scroll',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          textScaler: TextScaler.linear(2),
        ),
        child: Scaffold(body: StkLegalAcceptancePanel(
          today: DateTime(2026, 11, 17),
          birthDate: DateTime(2004, 6, 12),
          documents: approved,
          subjectType: StkLegalSubjectType.guest,
          subjectId: 'guest-test',
          locale: 'es-PE',
          onViewTerms: () async => true,
          onViewPrivacy: () async => true,
          onAccepted: (_) {},
          onDecline: () {},
        )),
      ),
    ));
    final continueButton = find.byKey(
      const ValueKey('stk_legal_continue'),
    );
    // At 320dp / 200% the CTA is initially unbuilt because of lazy
    // scrolling. Scroll until it is actually in the element tree.
    await tester.scrollUntilVisible(
      continueButton, 160, scrollable: find.byType(Scrollable).first,
    );
    expect(continueButton, findsOneWidget);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final decline = find.byKey(const ValueKey('stk_legal_decline'));
    await tester.scrollUntilVisible(
      decline, 160, scrollable: find.byType(Scrollable).first,
    );
    expect(decline, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
