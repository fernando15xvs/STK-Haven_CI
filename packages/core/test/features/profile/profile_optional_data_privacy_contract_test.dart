import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile review is local and never auto-copies demographic information', () {
    final page=File(
      'lib/features/profile/presentation/pages/personal_profile_page.dart',
    ).readAsStringSync();
    expect(page,contains('profile_view_optional_data'));
    expect(page,contains('SelectableText(data)'));
    expect(page,contains("'dateOfBirth':draft.dateOfBirth?.toIso8601String()"));
    expect(page,contains('profile_clear_optional_data'));
    expect(page,contains('clearDateOfBirth:true'));
    expect(page,contains('clearGenderIdentity:true'));
    expect(page,contains('clearEquationSexForEnergy:true'));
    expect(page,contains('Se aplicará al pulsar Guardar perfil.'));
    expect(page,isNot(contains('Clipboard.setData')));
  });
}
