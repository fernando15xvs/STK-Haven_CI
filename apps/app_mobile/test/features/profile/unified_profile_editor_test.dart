import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/profile/application/profile_edit_policy.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/profile/presentation/pages/personal_profile_page.dart';

class _Profile extends UserExperienceProfileNotifier {
  int saves=0;
  @override
  Future<UserExperienceProfile> build() async => const UserExperienceProfile(displayName:'Original',
    trainingDaysPerWeek:5, faithPreference:FaithContentPreference.disabled);
  @override
  Future<UserExperienceProfile> saveProfileEdit({required UserExperienceProfile original,
    required UserExperienceProfile draft}) async {
    saves++;
    final updated=ProfileEditPolicy.merge(original:original,draft:draft,current:state.value!,now:DateTime(2026));
    state=AsyncData(updated);
    return updated;
  }
}

void main(){
  testWidgets('one editor saves identity and training together, avatars are on demand',(tester)async{
    final fixture=_Profile();
    await tester.pumpWidget(ProviderScope(overrides:[userExperienceProfileProvider.overrideWith(()=>fixture)],
      child:MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(
        onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const PersonalProfilePage())),
        child:const Text('Abrir')))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Elegir foto'),findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile_change_avatar')));
    await tester.pumpAndSettle();
    expect(find.text('Elegir foto'),findsOneWidget);
    await tester.tap(find.text('🌱'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first,'Nuevo');
    await tester.ensureVisible(find.text('Preferencias de entrenamiento'));
    await tester.tap(find.text('Preferencias de entrenamiento'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.widgetWithText(ChoiceChip,'4'),120);
    await tester.tap(find.widgetWithText(ChoiceChip,'4'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Guardar perfil'),180);
    await tester.tap(find.text('Guardar perfil'));
    await tester.pumpAndSettle();
    expect(fixture.saves,1);
    final saved=await fixture.future;
    expect(saved.displayName,'Nuevo');
    expect(saved.trainingDaysPerWeek,4);
    expect(saved.avatarEmoji,'🌱');
    expect(find.text('Abrir'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
