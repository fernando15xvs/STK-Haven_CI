import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Perfil exposes a mobile legal and privacy page, not a web route', () {
    final profile = File(
      'lib/features/profile/presentation/pages/profile_page.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/profile/presentation/pages/profile_settings_page.dart',
    ).readAsStringSync();
    final privacy = File(
      'lib/features/profile/presentation/pages/stk_mobile_privacy_page.dart',
    ).readAsStringSync();
    expect(profile, contains("ValueKey('profile_open_settings')"));
    expect(profile, contains('const ProfileSettingsPage()'));
    expect(settings, contains("title: 'Legal y privacidad'"));
    expect(settings, contains('const StkMobilePrivacyPage()'));
    expect(privacy, contains('Supabase.instance.client.auth.currentUser?.id'));
    expect(privacy, contains('StkLegalSubjectType.authenticated'));
    expect(privacy, contains('StkLegalSubjectType.guest'));
    expect(privacy, contains('acceptanceSource: \'legal_settings\''));
    expect(privacy, contains('StkMobileOptionalConsentStore'));
    expect(privacy, contains("ValueKey('stk_revoke_optional_consents')"));
    expect(privacy, contains('StkMobileLegalConfig.documents'));
    expect(privacy, isNot(contains('apps/app_web')));
  });

  test('existing profile is saved before legal receipt, with identity recheck',
      () {
    final privacy = File(
      'lib/features/profile/presentation/pages/stk_mobile_privacy_page.dart',
    ).readAsStringSync();
    final profileWrite = privacy.indexOf(
      'await ref.read(userExperienceProfileProvider.notifier).updateProfile(');
    final receiptWrite = privacy.indexOf(
      'await _receipts.saveAuthenticated(receipt, activeUserId: uid)');
    expect(profileWrite, greaterThan(0));
    expect(receiptWrite, greaterThan(profileWrite));
    expect(privacy, contains('receipt.isCurrentFor('));
    expect(privacy, contains('if (current == null)'));
    expect(privacy, contains(
      'uid != Supabase.instance.client.auth.currentUser?.id'));
    expect(privacy, isNot(contains(
      'stk_set_adult_nutrition_verification(')));
  });

  test('new 15+ Food Vision checks consent before ALL image requests', () {
    final core = File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    final mobile = File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page_mobile.dart',
    ).readAsStringSync();
    expect(core, contains('requestPhotoAnalysisConsent'));
    expect(core, contains('final allowed = await checkConsent()'));
    expect(core, contains('if (!allowed)'));
    expect(core.indexOf('final allowed = await checkConsent()'),
        lessThan(core.indexOf(
          'final estimate = await FoodVisionService(Supabase.instance.client).analyze(',
        )));
    expect(mobile, contains('StkMobileLegalConfig.enabled'));
    expect(mobile, contains('_requestPhotoConsent'));
    expect(mobile, contains('StkOptionalConsentPurpose.foodVisionAi'));
    expect(mobile, contains('legalReceipt: receipt'));
    expect(mobile, contains('activeUserId: Supabase.instance.client.auth.currentUser?.id'));
    expect(mobile, contains("'No enviar'"));
    expect(mobile, contains("'Permitir análisis'"));
  });

  test('onboarding uses the actual current UID and never promotes guests', () {
    final mobile = File(
      'lib/features/onboarding/presentation/pages/onboarding_page.dart',
    ).readAsStringSync();
    expect(mobile, contains('StkLegalSubjectType.authenticated'));
    expect(mobile, contains('activeUid = Supabase.instance.client.auth.currentUser?.id'));
    expect(mobile, contains('store.saveAuthenticated('));
    expect(mobile, contains('store.saveGuest(legalReceipt)'));
    expect(mobile, contains('if (activeUid != null)'));
    expect(mobile, isNot(contains('stk_set_adult_nutrition_verification(')));
    expect(mobile, isNot(contains('service_role')));
  });
}
