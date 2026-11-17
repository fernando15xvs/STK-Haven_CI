import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/core/theme/appearance_theme.dart';
import 'package:core/domain/models/appearance_settings.dart';
import 'package:core/features/onboarding/application/stk_legal_acceptance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/onboarding/presentation/widgets/stk_legal_acceptance_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const legalFixture = StkLegalDocumentSet(
    termsVersion: 'approved-test-v1',
    termsSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    termsUrl: 'https://example.org/terms',
    privacyVersion: 'approved-test-v1',
    privacySha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    privacyUrl: 'https://example.org/privacy',
    approvedAndPublished: true,
  );

  setUpAll(() async {
    final loader = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/fonts/Outfit-Variable.ttf'));
    await loader.load();
  });

  testWidgets(
    'Phase 5: 216 legal layouts, 24 rendered visual screenshots, no overflow',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dir = Directory('build/stk_legal_visual_qa')
        ..createSync(recursive: true);
      var captures = 0;
      var layouts = 0;

      for (final width in <double>[320, 390, 430]) {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;

        for (final scale in <double>[1, 1.6, 2]) {
          for (final theme in const <(Brightness, bool)>[
            (Brightness.light, false),
            (Brightness.dark, false),
            (Brightness.dark, true),
          ]) {
            for (final accent in AppAccent.values) {
              final appearance = AppearanceSettings(
                accent: accent,
                oledBlack: theme.$2,
              );
              await tester.pumpWidget(MaterialApp(
                theme: AppearanceTheme.build(appearance, theme.$1),
                home: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: RepaintBoundary(
                      key: const ValueKey('stk_legal_qa_capture'),
                      child: StkLegalAcceptancePanel(
                        today: DateTime(2026, 11, 17),
                        birthDate: DateTime(2010, 7, 5),
                        documents: legalFixture,
                        subjectType: StkLegalSubjectType.guest,
                        subjectId: 'qa-device',
                        locale: 'es-PE',
                        onViewTerms: () async => true,
                        onViewPrivacy: () async => true,
                        onAccepted: (_) {},
                        onDecline: () {},
                      ),
                    ),
                  ),
                ),
              ));
              await tester.pumpAndSettle();
              layouts++;
              expect(
                tester.takeException(), isNull,
                reason: 'width=$width scale=$scale theme=${theme.$1} '
                    'oled=${theme.$2} accent=$accent',
              );
              expect(find.text('Antes de comenzar'), findsOneWidget);
              // The CTA can be lazily unmounted at 320dp/200%: a separate
              // scrolling test below checks its disabled/active states.

              if (width == 390 && scale == 1.6) {
                await tester.runAsync(() async {
                  final boundary = tester.renderObject<RenderRepaintBoundary>(
                    find.byKey(const ValueKey('stk_legal_qa_capture')),
                  );
                  final image = await boundary.toImage(pixelRatio: 2);
                  try {
                    final data = await image.toByteData(
                      format: ui.ImageByteFormat.png,
                    );
                    expect(data, isNotNull);
                    final themeName = theme.$2
                        ? 'oled'
                        : theme.$1 == Brightness.dark ? 'dark' : 'light';
                    final path = '${dir.path}/legal_${themeName}_'
                        '${accent.name}.png';
                    final bytes = data!.buffer.asUint8List(
                      data.offsetInBytes, data.lengthInBytes,
                    );
                    final file = File(path)..writeAsBytesSync(bytes);
                    expect(file.lengthSync(), greaterThan(1000));
                    captures++;
                  } finally {
                    image.dispose();
                  }
                });
              }
            }
          }
        }
      }
      expect(layouts, 3 * 3 * 3 * AppAccent.values.length);
      expect(captures, 3 * AppAccent.values.length);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('320dp / 200%: both legal links, CTA and exit remain reachable',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    var accepted = false;
    var declined = false;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          textScaler: TextScaler.linear(2),
        ),
        child: Scaffold(
          body: StkLegalAcceptancePanel(
            today: DateTime(2026, 11, 17),
            birthDate: DateTime(2007, 3, 4),
            documents: legalFixture,
            subjectType: StkLegalSubjectType.guest,
            subjectId: 'qa-guest',
            locale: 'es-PE',
            onViewTerms: () async => true,
            onViewPrivacy: () async => true,
            onAccepted: (_) => accepted = true,
            onDecline: () => declined = true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stk_terms_link')),
      130, scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('stk_terms_link')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stk_privacy_link')),
      130, scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('stk_privacy_link')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stk_confirm_15_plus')),
      130,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('stk_confirm_15_plus')));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stk_accept_terms')),
      130,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('stk_accept_terms')));
    final cta = find.byKey(const ValueKey('stk_legal_continue'));
    await tester.scrollUntilVisible(
      cta, 130, scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(cta).onPressed, isNotNull);
    await tester.tap(cta);
    expect(accepted, isTrue);
    final exit = find.byKey(const ValueKey('stk_legal_decline'));
    await tester.scrollUntilVisible(
      exit, 130, scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(exit);
    expect(declined, isTrue);
    expect(tester.takeException(), isNull);
  });
}
