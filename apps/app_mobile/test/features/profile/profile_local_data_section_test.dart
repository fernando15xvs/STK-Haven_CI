import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/application/profile_edit_policy.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/profile/presentation/widgets/profile_local_data_section.dart';

class _Profile extends UserExperienceProfileNotifier {
  @override
  Future<UserExperienceProfile> build() async=>UserExperienceProfile(
    dateOfBirth:DateTime(2000,2,3),eligibilityBirthDate:DateTime(2000,2,3),
    genderIdentity:GenderIdentity.man,optionalDemographicsConsented:true,trainingDaysPerWeek:5);
  @override
  Future<UserExperienceProfile> setOptionalDemographicConsent(bool enabled) async {
    final next=ProfileEditPolicy.withDemographicConsent(state.value!,enabled,DateTime(2026));
    state=AsyncData(next);
    return next;
  }
}

void main(){
  testWidgets('privacy review is readable and revocation preserves unrelated preferences',(tester)async{
    final fixture=_Profile();
    await tester.pumpWidget(ProviderScope(overrides:[userExperienceProfileProvider.overrideWith(()=>fixture)],
      child:const MaterialApp(home:Scaffold(body:SingleChildScrollView(child:ProfileLocalDataSection())))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile_view_optional_data')));
    await tester.pumpAndSettle();
    expect(find.text('03/02/2000'),findsOneWidget);
    expect(find.text('Hombre'),findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile_clear_optional_data')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar datos'));
    await tester.pumpAndSettle();
    final saved=await fixture.future;
    expect(saved.dateOfBirth,isNull);
    expect(saved.optionalDemographicsConsented,isFalse);
    expect(saved.eligibilityBirthDate,DateTime(2000,2,3));
    expect(saved.trainingDaysPerWeek,5);
    expect(tester.takeException(),isNull);
  });
}
