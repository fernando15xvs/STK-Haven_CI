import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web Perfil cannot replace programs through legacy onboarding routes', () {
    final profile = File(
      'lib/features/profile/presentation/profile_page_web.dart',
    ).readAsStringSync();
    final layout = File('lib/core/layout/web_layout.dart').readAsStringSync();

    expect(profile, isNot(contains('replaceProgram(')));
    expect(profile, isNot(contains('removeActiveProgram(')));
    expect(profile, isNot(contains("title: 'Programa de entrenamiento'")));
    expect(profile, isNot(contains('presetPrograms')));
    expect(layout, contains('TrainingProgramsPage()'));
  });
}
