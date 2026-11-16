import 'dart:io';

import 'package:core/domain/models/user_experience_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guidance is opt-in by declared age, not an adult verification grant',(){
    final birthday=DateTime(2010,6,1);
    final youth=UserExperienceProfile(
      dateOfBirth:birthday,
      trainingExperience:TrainingExperience.beginner,
      trainingDaysPerWeek:6,
    );
    expect(youth.ageAt(DateTime(2026,11,15)),16);
    expect(const UserExperienceProfile().ageAt(DateTime(2026,11,15)),isNull);
    expect(youth.trainingDaysPerWeek,6); // No changes to the saved program.
  });

  test('existing plans stay visible and juveniles see technique and rest advice',(){
    final page=File(
      'lib/features/programs/presentation/pages/training_programs_page.dart',
    ).readAsStringSync();
    expect(page,contains('final isMinor=(profile?.ageAt(DateTime.now()) ?? 99)<18;'));
    expect(page,contains("'training_youth_guidance'"));
    expect(page,contains("'training_age_unknown_guidance'"));
    expect(page,contains('if(isMinor || ageUnknown)'));
    expect(page,contains('No necesitas indicar tu edad para entrenar.'));
    expect(page,contains('no se instalará un programa automáticamente.'));
    expect(page,contains('Prioriza técnica, progresión gradual y recuperación.'));
    expect(page,contains('no instalamos automáticamente un programa adulto.'));
    expect(page,contains('Expanded(child:programs.isEmpty'));
    expect(page,contains('onActivate: () => ref'));
  });
}
