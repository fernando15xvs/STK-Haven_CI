import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Profile no longer owns programs or duplicates Motivation', () {
    final profile = File(
      'lib/features/profile/presentation/pages/profile_page.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/home/presentation/pages/home_screen.dart',
    ).readAsStringSync();
    expect(profile, isNot(contains('STK MOTIVATION')));
    expect(profile, isNot(contains('Mis audios y videos')));
    expect(profile, isNot(contains('PROGRAMA ACTUAL')));
    expect(profile, isNot(contains('replaceProgram(')));
    expect(profile, isNot(contains('ProgramPreviewModal')));
    expect(shell, contains("label: 'Motivation'"));
    expect(shell, contains('const MotivationPage()'));
  });

  test('Experience cannot silently revert the weight unit', () {
    final experience = File(
      '../../packages/core/lib/features/profile/presentation/pages/experience_preferences_page.dart',
    ).readAsStringSync();
    expect(experience, isNot(contains('setWeightUnit(draft.weightUnit)')));
    expect(experience, isNot(contains('SegmentedButton<WeightUnit>')));
    expect(experience, isNot(contains('workoutRemindersWanted: value')));
  });
}
