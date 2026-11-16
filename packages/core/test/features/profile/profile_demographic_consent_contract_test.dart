import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('profile requires explicit demographic choice and offers view/delete',(){
    final profile=File(
      'lib/features/profile/presentation/pages/personal_profile_page.dart',
    ).readAsStringSync();
    expect(profile,contains("ValueKey('profile_optional_demographics_consent')"));
    expect(profile,contains('Autorizar datos demográficos opcionales'));
    expect(profile,contains('Solo se guardan localmente'));
    expect(profile,contains('optionalDemographicsConsented:true'));
    expect(profile,contains('optionalDemographicsConsentedAt:DateTime.now()'));
    expect(profile,contains('optionalDemographicsConsented:false'));
    expect(profile,contains('clearOptionalDemographicsConsentAt:true'));
    expect(profile,contains('Desactivar datos opcionales'));
    expect(profile,contains('Quitar del borrador'));
    expect(profile,contains('if(confirmed!=true || !mounted)return;'));
    expect(profile,contains('Se aplicará al guardar.'));

    expect(profile,contains('clearDateOfBirth:true'));
    expect(profile,contains('clearGenderIdentity:true'));
    expect(profile,contains('clearEquationSexForEnergy:true'));
    expect(profile,contains('onPressed:!draft.optionalDemographicsConsented?null:'));
    expect(profile,contains('changedDemographics'));
    expect(profile,contains('optionalDemographicsUpdatedAt:changedDemographics'));
    expect(profile,contains("ValueKey('profile_view_optional_data')"));
    expect(profile,contains("ValueKey('profile_clear_optional_data')"));
    expect(profile,contains('SelectableText(data)'));
    expect(profile,contains("'optionalDemographicsConsentedAt':"));
    expect(profile,contains("'optionalDemographicsUpdatedAt':"));
    expect(profile,isNot(contains('Clipboard.setData')));
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
