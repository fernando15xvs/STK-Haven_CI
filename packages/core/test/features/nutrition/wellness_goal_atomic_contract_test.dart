import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sensor steps and reminders commit to Hive before the UI changes',(){
    final source=File('lib/features/home/application/wellness_provider.dart')
      .readAsStringSync();
    void assertsSavedBeforeState(String method,String saveMethod,
      {int occurrence=0}) {
      var from=0;
      var start=-1;
      for(var i=0;i<=occurrence;i++){
        start=source.indexOf('Future<void> $method(',from);
        expect(start,greaterThanOrEqualTo(0));
        from=start+1;
      }
      // Match a complete method-closing line, not the `}) async {`
      // that ends the multiline parameter list of setSteps.
      final end=source.indexOf('\n  }\n',start);
      expect(end,greaterThan(start));
      final body=source.substring(start,end);
      final save=body.indexOf('await _repository.$saveMethod(updated);');
      final notify=body.indexOf('state=updated;');
      expect(save,greaterThanOrEqualTo(0));
      expect(notify,greaterThan(save));
    }
    assertsSavedBeforeState('setReminderEnabled',
      'saveHydrationPreferences');
    assertsSavedBeforeState('setReminderHour',
      'saveHydrationPreferences');
    assertsSavedBeforeState('markReminderSent',
      'saveHydrationPreferences');
    assertsSavedBeforeState('setReminderEnabled',
      'saveStepGoalPreferences',occurrence:1);
    assertsSavedBeforeState('setReminderCadence',
      'saveStepGoalPreferences');
    assertsSavedBeforeState('setSteps','saveSteps');
  });

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
