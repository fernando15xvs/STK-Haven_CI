import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String core(String relative) => File('../../packages/core/$relative')
      .readAsStringSync();
  String mobile(String relative) => File('lib/$relative').readAsStringSync();

  test('adult nutrition reads reviewed backend capability before legacy RPC',
      () {
    final access = core(
      'lib/features/nutrition/data/nutrition_adult_access_service.dart',
    );
    final newer = access.indexOf("client.rpc('stk_get_nutrition_capabilities')");
    final old = access.indexOf("client.rpc('stk_has_adult_nutrition_access')");
    expect(newer, greaterThanOrEqualTo(0));
    expect(old, greaterThan(newer));
    expect(access, contains("error.code == 'PGRST202'"));
    expect(access, contains("error.code == '42883'"));
    expect(access, contains('StkNutritionServerCapabilities.parse(result)'));
    expect(access, contains('return parsed?.personalizedAdultEnergy'));
    expect(access, isNot(contains('user_metadata')));
  });

  test('Food Vision checks privileged capacity for authenticated request UID',
      () {
    final edge = File('../../supabase/functions/food-vision-ai/index.ts')
        .readAsStringSync();
    expect(edge, contains('const userId = ctx.userClaims?.id;'));
    expect(edge, contains("'stk_service_can_use_nutrition_capability_for_session'"));
    expect(edge, contains('p_session_id: sessionId'));
    expect(edge, contains('const claimedSessionId ='));
    expect(edge, contains("sessionId !== null"));
    expect(edge, contains("p_capability: 'personalizedAdultEnergy'"));
    expect(edge, contains('p_user_id: userId'));
    expect(edge, contains('const isAnonymousJwt ='));
    expect(edge, contains('payload.adultNumericNutrition === true && !isAnonymousJwt'));
    expect(edge, contains('ctx.userClaims as { is_anonymous?: boolean }'));

    expect(edge, contains("capabilityError.code === 'PGRST202'"));
    expect(edge, contains("capabilityError.code === '42883'"));
    expect(edge, contains('permitted === true'));
    expect(edge, contains('if (!adultNumericNutrition) {'));
    expect(edge, isNot(contains('p_user_id: payload.userId')));
  });

  test('published 15+ onboarding and account review require server receipts',
      () {
    final onboarding = mobile(
      'features/onboarding/presentation/pages/onboarding_page.dart',
    );
    final privacy = mobile(
      'features/profile/presentation/pages/stk_mobile_privacy_page.dart',
    );
    final gateway = core(
      'lib/features/onboarding/data/stk_legal_server_receipt_service.dart',
    );
    expect(onboarding, contains('StkLegalServerReceiptService('));
    expect(onboarding, contains('recordAcceptance('));
    expect(onboarding, contains('if (!recorded)'));
    expect(privacy, contains('recordAcceptance('));
    expect(privacy, contains('if (!remoteAccepted)'));
    expect(privacy, contains('revokeCurrentAcceptance()'));
    expect(privacy, contains("ValueKey('stk_revoke_legal_acceptance')"));
    expect(gateway, contains("client.rpc('stk_get_current_legal_release')"));
    expect(gateway, contains("client.rpc('stk_record_legal_acceptance'"));
    expect(gateway, contains("client.rpc('stk_revoke_legal_acceptance')"));
    expect(gateway, contains('sameSession()'));
    expect(gateway, isNot(contains('stk_set_adult_nutrition_verification')));
  });

  test('revoked remote legal receipts block restored photo consent', () {
    final mobileNutrition = mobile(
      'features/nutrition/presentation/pages/nutrition_intelligence_page_mobile.dart',
    );
    final check = mobileNutrition.indexOf(
      ".rpc('stk_get_nutrition_capabilities')",
    );
    final cachedConsent = mobileNutrition.indexOf('if (consentStore.isGranted(');
    expect(check, greaterThanOrEqualTo(0));
    expect(cachedConsent, greaterThan(check));
    expect(mobileNutrition, contains('capabilities?.legalCurrent != true'));
    expect(mobileNutrition, contains('!samePhotoConsentSession()'));
    expect(mobileNutrition, contains('StkNutritionServerCapabilities.parse(response)'));
  });

  test('release is disabled until approved and numerical grants stay remote',
      () {
    final config = mobile(
      'features/onboarding/presentation/stk_mobile_legal_config.dart',
    );
    final grants = core(
      'lib/features/nutrition/data/stk_nutrition_server_capabilities.dart',
    );
    expect(config, contains("'STK_ENABLE_15_PLUS_ONBOARDING'"));
    expect(config, contains('defaultValue: false'));
    expect(config, contains("'STK_LEGAL_APPROVED_AND_PUBLISHED'"));
    expect(grants, contains('if ((adult || food) && !legal) return null;'));
    expect(grants, isNot(contains("response['dob']")));
  });
}
