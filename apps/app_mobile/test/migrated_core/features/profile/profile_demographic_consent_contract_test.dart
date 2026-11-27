import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('editor requires explicit consent and privacy owns review and withdrawal',(){
    final profile=File('lib/features/profile/presentation/pages/personal_profile_page.dart').readAsStringSync();
    final local=File('lib/features/profile/presentation/widgets/profile_local_data_section.dart').readAsStringSync();
    final privacy=File('lib/features/profile/presentation/pages/stk_mobile_privacy_page.dart').readAsStringSync();
    final policy=File('../../packages/core/lib/features/profile/application/profile_edit_policy.dart').readAsStringSync();
    expect(profile,contains('Autorizar datos demográficos opcionales'));
    expect(profile,contains('Se guardan en tu dispositivo'));
    expect(profile,contains('Si exportas o subes una copia de seguridad'));
    expect(profile,contains('if(confirmed!=true || !mounted)return false;'));
    expect(profile,contains('ProfileEditPolicy.withDemographicConsent'));
    expect(profile,contains('saveProfileEdit('));
    expect(privacy,contains('const ProfileLocalDataSection()'));
    expect(local,contains('profile_optional_demographics_consent'));
    expect(local,contains('profile_view_optional_data'));
    expect(local,contains('profile_clear_optional_data'));
    expect(local,contains('setOptionalDemographicConsent(enabled)'));
    expect(local,contains('Las copias anteriores no se modifican.'));
    expect(policy,contains('clearOptionalDemographicsConsentAt:true'));
    expect(policy,contains('clearDateOfBirth:true'));
    expect(policy,contains('clearGenderIdentity:true'));
    expect(policy,contains('clearEquationSexForEnergy:true'));
    expect(policy,contains('changedDemographics'));
    expect(policy,contains('optionalDemographicsUpdatedAt'));
    expect(profile,isNot(contains('profile_clear_optional_data')));
  });

  test('adult calculator never preloads unconsented legacy birthday or equation',(){
    final nutrition=File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    expect(nutrition,contains('optionalDemographicsConsented==true'));
    expect(nutrition,contains('permittedDemographics?.ageAt(DateTime.now())'));
    expect(nutrition,contains('permittedDemographics?.equationSexForEnergy'));
    expect(nutrition,contains('final consented=savedDemographics?.optionalDemographicsConsented==true;'));
    expect(nutrition,contains('(consented?savedDemographics?.ageAt(DateTime.now()):null)'));
    expect(nutrition,contains('(consented?savedDemographics?.equationSexForEnergy:null)'));
    expect(nutrition,contains("if (!hasAdultAccess)"));
  });
}
