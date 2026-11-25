import 'package:core/domain/models/user_experience_profile.dart';
import 'package:gym_tracker/features/profile/presentation/pages/personal_profile_page.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
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

Finder editorScroll() => find.descendant(
  of: find.byKey(const ValueKey('profile_editor_scroll')),
  matching: find.byWidgetPredicate((widget) =>
    widget is Scrollable && widget.axisDirection == AxisDirection.down),
);

void main() {
  Future<void> pumpProfile(WidgetTester tester,
      {required double width, required double scale, bool openTraining = false}) async {
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
          child: PersonalProfilePage(openTraining: openTraining),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final scenario in [(320.0, 2.0), (390.0, 1.0), (430.0, 1.6)]) {
    testWidgets('mobile demographics stay available at ${scenario.$1}dp '
        'and ${scenario.$2}x text', (tester) async {
      await pumpProfile(tester,
          width: scenario.$1, scale: scenario.$2);
      expect(find.text('Datos personales'), findsOneWidget);
      await tester.ensureVisible(find.text('Datos personales'));
      await tester.tap(find.text('Datos personales'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile_mobile_demographic_editor')),
        180,
        scrollable: editorScroll(),
      );
      expect(find.text('Editar fecha, género y cálculo'), findsOneWidget);
      // Demographic DOB is independent of the separate eligibility DOB.
      expect(find.text('Fecha: 03/02/2000'), findsOneWidget);
      // SliverChildListDelegate can build the tile before it is hittable.
      // Place its TITLE inside the actual viewport before tapping it.
      await tester.ensureVisible(find.text('Editar fecha, género y cálculo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar fecha, género y cálculo'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile_birth_date')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('legacy follow-up opens the same editor with training expanded', (tester) async {
    await pumpProfile(tester, width: 430, scale: 1, openTraining: true);
    expect(find.text('Editar perfil'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Objetivo principal'), 150,
      scrollable: editorScroll());
    expect(find.text('Objetivo principal'), findsOneWidget);
    expect(find.text('Personalización'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
