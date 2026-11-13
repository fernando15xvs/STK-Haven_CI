import 'package:core/features/programs/application/program_duration_choices.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recommended plan durations remain unique and ordered', () {
    expect(ProgramDurationChoices.forSelected(8),
        [4, 6, 8, 10, 12, 16, 20, 24]);
  });

  test('adding a week always produces a selectable dropdown value', () {
    for (final initial in [4, 8, 24, 25, 52]) {
      final updated = ProgramDurationChoices.addWeek(initial);
      final options = ProgramDurationChoices.forSelected(updated);
      expect(updated, initial + 1);
      expect(options.where((value) => value == updated), hasLength(1));
      expect(options, orderedEquals([...options]..sort()));
    }
  });

  test('adding a week rejects invalid duration', () {
    expect(() => ProgramDurationChoices.addWeek(0), throwsArgumentError);
    expect(() => ProgramDurationChoices.addWeek(-1), throwsArgumentError);
  });
}
