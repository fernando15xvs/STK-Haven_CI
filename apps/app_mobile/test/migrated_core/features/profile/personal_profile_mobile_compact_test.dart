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
      await tester.ensureVisible(find.byKey(const ValueKey('profile_birth_date')));
      expect(find.text('Fecha de nacimiento'), findsOneWidget);
      expect(find.text('03/02/2000'), findsOneWidget);
      if(scenario.$2==1){
        await tester.tap(find.byKey(const ValueKey('profile_birth_date')));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('legacy follow-up opens the same editor with training expanded', (tester) async {
    await pumpProfile(tester, width: 430, scale: 1, openTraining: true);
    expect(find.text('Editar perfil'), findsOneWidget);
    await tester.ensureVisible(find.text('Objetivo principal'));
    expect(find.text('Objetivo principal'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
