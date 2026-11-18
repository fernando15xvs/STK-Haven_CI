import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/presentation/pages/personal_profile_page.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _PreviewProfile extends UserExperienceProfileNotifier {
  @override
  Future<UserExperienceProfile> build() async => UserExperienceProfile(
        displayName: 'Atleta',
        dateOfBirth: DateTime(2000, 2, 3),
        eligibilityBirthDate: DateTime(2001, 4, 5),
        optionalDemographicsConsented: true,
      );
}

void main() {
  Future<void> pumpProfile(WidgetTester tester,
      {required bool compact, required double width, required double scale}) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userExperienceProfileProvider.overrideWith(_PreviewProfile.new),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1000),
            textScaler: TextScaler.linear(scale),
          ),
          child: PersonalProfilePage(mobileCompactLayout: compact),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final scenario in [(320.0, 2.0), (390.0, 1.0), (430.0, 1.6)]) {
    testWidgets('mobile demographics stay available at ${scenario.$1}dp '
        'and ${scenario.$2}x text', (tester) async {
      await pumpProfile(tester,
          compact: true, width: scenario.$1, scale: scenario.$2);
      expect(find.text('Datos personales'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile_mobile_demographic_editor')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Editar fecha, género y cálculo'), findsOneWidget);
      // Demographic DOB is independent of the separate eligibility DOB.
      expect(find.text('Fecha: 03/02/2000'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('profile_mobile_demographic_editor')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile_birth_date')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('web-compatible default retains expanded original editing',
      (tester) async {
    await pumpProfile(tester, compact: false, width: 430, scale: 1);
    expect(find.text('Cómo quieres aparecer'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile_mobile_demographic_editor')),
        findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile_birth_date')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('profile_birth_date')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
