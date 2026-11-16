import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('Profile keeps legacy training follow-up optional and dismissible',(){
    final profile=File(
      'lib/features/profile/presentation/pages/profile_page.dart',
    ).readAsStringSync();
    expect(profile,contains('savedProfile?.needsOptionalTrainingFollowup == true'));
    expect(profile,contains("ValueKey('profile_legacy_training_followup')"));
    expect(profile,contains("ValueKey('profile_complete_legacy_training')"));
    expect(profile,contains("ValueKey('profile_skip_legacy_training')"));
    expect(profile,contains("child:const Text('Ahora no')"));
    expect(profile,contains('legacyTrainingFollowupDismissed:true'));
    expect(profile,contains('const ExperiencePreferencesPage()'));
    expect(profile,contains('Tus rutinas, respuestas anteriores y cuenta se conservan.'));
    // It only links to an existing editing route. No forced onboarding,
    // sign-out, remote consent creation or automated recommendations.
    expect(profile,isNot(contains('pushReplacement')));
    expect(profile,isNot(contains('signOut(')));
    expect(profile,isNot(contains('installProgram(')));
  });

}
