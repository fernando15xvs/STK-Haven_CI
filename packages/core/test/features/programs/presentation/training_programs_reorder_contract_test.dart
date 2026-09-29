import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plan routine order uses drag reorder instead of arrow controls', () {
    final source = File(
      'lib/features/programs/presentation/pages/training_programs_page.dart',
    ).readAsStringSync();

    expect(source, contains('ReorderableListView.builder'));
    expect(source, contains('ReorderableDragStartListener'));
    expect(source, contains('Arrastra el asa para cambiar el orden'));
    expect(source, isNot(contains('Icons.arrow_upward_rounded')));
    expect(source, isNot(contains('Icons.arrow_downward_rounded')));
  });
}
