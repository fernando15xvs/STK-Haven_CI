import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile scans ask consent for every upload, including legacy mode', () {
    final mobile = File(
      'lib/features/nutrition/presentation/pages/'
      'nutrition_intelligence_page_mobile.dart',
    ).readAsStringSync();
    final core = File(
      '../../packages/core/lib/features/nutrition/presentation/pages/'
      'nutrition_intelligence_page.dart',
    ).readAsStringSync();
    expect(mobile, contains('requestPhotoAnalysisConsent: _requestPhotoConsent'));
    expect(mobile, contains('return _requestOneTimePhotoConsent();'));
    expect(mobile, contains('if (!StkMobileLegalConfig.enabled)'));
    expect(mobile, contains('if (!docs.canCollectAcceptance) return false;'));
    expect(mobile, contains('openingUser == Supabase.instance.client.auth.currentUser?.id'));
    expect(mobile, contains('openingToken == Supabase.instance.client.auth.currentSession?.accessToken'));
    expect(mobile, contains('!samePhotoConsentSession()'));
    expect(mobile, contains('tokenAtStart == Supabase.instance.client.auth.currentSession?.accessToken'));
    expect(mobile, contains("'Enviar esta foto'"));
    expect(mobile, contains("'No enviar'"));
    expect(mobile, contains('approved == true'));
    expect(core, contains('final allowed = await checkConsent()'));
    expect(core.indexOf('final allowed = await checkConsent()'),
        lessThan(core.indexOf(
          'final estimate = await FoodVisionService(Supabase.instance.client).analyze(',
        )));
    expect(core, contains('if (!allowed)'));
    expect(core, contains("No se envió la fotografía"));
  });

  test('unpublished terms do not create durable permissions or adult access', () {
    final mobile = File(
      'lib/features/nutrition/presentation/pages/'
      'nutrition_intelligence_page_mobile.dart',
    ).readAsStringSync();
    final a = mobile.indexOf('Future<bool> _requestOneTimePhotoConsent()');
    final b = mobile.indexOf(
      'Future<NutritionPhoto?> _pickPhoto(',
    );
    expect(a, greaterThanOrEqualTo(0));
    expect(b, greaterThan(a));
    final legacy = mobile.substring(a, b);
    expect(legacy, isNot(contains('setGranted(')));
    expect(legacy, isNot(contains('saveGuest(')));
    expect(legacy, isNot(contains('adultVerified')));
  });
}
