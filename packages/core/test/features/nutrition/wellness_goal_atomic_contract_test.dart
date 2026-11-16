import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('water and steps goals are not published before persistence succeeds', () {
    final source=File('lib/features/home/application/wellness_provider.dart')
      .readAsStringSync();
    final water=source.substring(
      source.indexOf('Future<void> setTargetMl('),
      source.indexOf('Future<void> setReminderEnabled(',source.indexOf('Future<void> setTargetMl(')),
    );
    final steps=source.substring(
      source.indexOf('Future<void> setTargetSteps('),
      source.indexOf('Future<void> setReminderEnabled(',source.indexOf('Future<void> setTargetSteps(')),
    );
    expect(water.indexOf('await _repository.saveHydrationPreferences(updated);'),
      lessThan(water.indexOf('state=updated;')));
    expect(steps.indexOf('await _repository.saveStepGoalPreferences(updated);'),
      lessThan(steps.indexOf('state=updated;')));
  });
}
