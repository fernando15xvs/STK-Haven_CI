import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding v3 personal data is optional and saves in Medidas once', () {
    final source = File('lib/features/onboarding/presentation/pages/onboarding_page.dart')
        .readAsStringSync();
    expect(source, contains('static const int _legacyPageCount = 7'));
    expect(source, contains('int get _pageCount => _legalFlowRequested ? 9 : _legacyPageCount;'));
    expect(source, contains('_personalStep()'));
    expect(source, contains("key: const ValueKey('onboarding_birth_date')"));
    expect(source, contains("key: const ValueKey('onboarding_save_first_measurement')"));
    expect(source, contains('if (_saveFirstMeasurement)'));
    expect(source, contains('bodyMeasurementProvider.notifier'));
    expect(source, contains("stk_onboarding_first_measurement_v3"));
    expect(source, contains("!ref.read(bodyMeasurementProvider).any"));
    expect(source, contains('WeightConverter.toCanonicalKg'));
    expect(source, isNot(contains('stk_has_adult_nutrition_access')));
  });

  test('optional demographic consent is explicit and never grants adult access',(){
    final page=File(
      'lib/features/onboarding/presentation/pages/onboarding_page.dart',
    ).readAsStringSync();
    expect(page,contains('bool _demographicConsent=false;'));
    expect(page,contains("ValueKey('onboarding_optional_demographic_consent')"));
    expect(page,contains('Autorizo guardar estos datos opcionales'));
    expect(page,contains('Pueden aparecer en una copia'));
    expect(page,contains('Puedes continuar sin ellos.'));
    expect(page,contains('dateOfBirth: _demographicConsent'));
    expect(page,contains('eligibilityBirthDate:'));
    expect(page,contains('(_legalFlowRequested ? _eligibilityBirthDate : _birthDate)'));
    expect(page,contains('genderIdentity: _demographicConsent?_genderIdentity:null'));
    expect(page,contains('equationSexForEnergy: _demographicConsent?_equationSexForEnergy:null'));
    expect(page,contains('optionalDemographicsConsented:_demographicConsent'));
    expect(page,contains('optionalDemographicsConsentedAt:_demographicConsentedAt'));
    expect(page,contains('onPressed: !_demographicConsent?null:'));
    expect(page,contains('onChanged: !_demographicConsent?null:'));
    expect(page,contains("_demographicConsent?'Autorizados':'Omitidos'"));
    expect(page,isNot(contains('stk_set_adult_nutrition_verification(')));
    expect(page,isNot(contains('service_role')));
  });

  test('undeclared age keeps training useful without adult preset auto-install',(){
    final page=File(
      'lib/features/onboarding/presentation/pages/onboarding_page.dart',
    ).readAsStringSync();
    expect(page,contains('OnboardingRecommendationService.recommend(profile)'));
    expect(page,contains("ValueKey('onboarding_unknown_age_safe_training')"));
    expect(page,contains('no instalaremos uno automáticamente.'));
    expect(page,contains('Puedes configurar rutinas después en Entrenar.'));
    expect(page,contains('if (recommended != null)'));
    expect(page,contains('_finish(installRecommended: false)'));
    expect(page,contains('completeOnboardingFromScratch()'));
  });

  test('15+ onboarding adds an age step and final legal gate only on mobile', () {
    final page = File(
      'lib/features/onboarding/presentation/pages/onboarding_page.dart',
    ).readAsStringSync();
    expect(page, contains('if (_legalFlowRequested) _ageStep()'));
    expect(page, contains('if (_legalFlowRequested) _legalStep()'));
    expect(page, contains('StkLegalAcceptancePanel('));
    expect(page, contains('StkAgeEligibility.canBeginNewAccount('));
    expect(page, contains('StkMobileLegalReceiptStore('));
    expect(page, contains('onDecline: _declineLegal'));
    expect(page, contains('if (_legalFlowRequested && !_legalDocs.canCollectAcceptance)'));
    expect(page, isNot(contains('stk_set_adult_nutrition_verification(')));
  });

  test('onboarding progress and welcome use shared Outfit tokens', () {
    final page=File(
      'lib/features/onboarding/presentation/pages/onboarding_page.dart',
    ).readAsStringSync();
    expect(page,contains('LinearProgressIndicator('));
    expect(page,contains('value: _currentIndex / (_pageCount - 1)'));
    expect(page,contains('style: AppTypography.displaySmall.copyWith('));
    expect(page,contains('style: AppTypography.bodyMedium.copyWith('));
  });

  test('nutrition uses Medidas rather than 70 kg and 170 cm fabricated values', () {
    final core = File(
      '../../packages/core/lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    final mobile = File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page_mobile.dart',
    ).readAsStringSync();
    expect(core, contains('LatestBodyMeasurements.fromRecords'));
    expect(core, contains('bodyMeasurementProvider'));
    expect(core, contains('onOpenMeasurements'));
    expect(core, contains('body.fingerprint'));
    expect(core, isNot(contains("TextEditingController(text: '70')")));
    expect(core, isNot(contains("TextEditingController(text: '170')")));
    expect(core, isNot(contains("TextEditingController(text: '25')")));
    expect(mobile, contains('const BodyMeasurementPage()'));
    expect(core, contains('nutritionAccessStateProvider(widget.verifiedAdultNutritionAccess)'));
    expect(core, contains('access.canViewNumericNutrition'));
  });
}
