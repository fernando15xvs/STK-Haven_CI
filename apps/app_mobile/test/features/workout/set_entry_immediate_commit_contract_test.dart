import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weight/reps/RIR commit on each change without a debounce timer', () {
    final source = File(
      'lib/features/workout/presentation/active_workout_page_content.dart',
    ).readAsStringSync();
    expect(source, contains('void _onFieldChanged() => _persistFields();'));
    expect(source, contains('onChanged: (_) => _onFieldChanged()'));
    expect(source, isNot(contains('Timer(const Duration(milliseconds: 500)')));
    expect(source, contains('_weightFocused'));
    expect(source, contains('_repsFocused'));
    expect(source, contains('_rirFocused'));
  });
}
