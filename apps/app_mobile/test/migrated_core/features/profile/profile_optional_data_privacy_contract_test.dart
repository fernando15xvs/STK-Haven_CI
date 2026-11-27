import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legal privacy shows understandable local data and never auto copies it', () {
    final page=File('lib/features/profile/presentation/widgets/profile_local_data_section.dart').readAsStringSync();
    expect(page,contains('profile_view_optional_data'));
    expect(page,contains(r'SelectableText(row.$2'));
    expect(page,contains('Fecha de nacimiento'));
    expect(page,contains('Fecha de autorización'));
    expect(page,contains('Última actualización'));
    expect(page,contains('profile_clear_optional_data'));
    expect(page,contains('setOptionalDemographicConsent'));
    expect(page,isNot(contains('JsonEncoder')));
    expect(page,isNot(contains('Clipboard.setData')));
  });
}
