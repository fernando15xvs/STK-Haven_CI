import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finalize CTA always exists and is not duplicated in the menu', () {
    final page = File('lib/features/workout/presentation/active_workout_page_content.dart').readAsStringSync();
    expect(page, contains('bottomNavigationBar: SafeArea('));
    expect(page, contains("label: 'Finalizar entrenamiento'"));
    expect(page, isNot(contains('floatingActionButton: allExercisesCompleted')));
    expect(page, isNot(contains("value: 'finish'")));
    expect(page, contains("child: const Text('Guardar incompleta')"));
  });

  test('empty workout returns without cancelling the active timer', () {
    final src = File('../../packages/core/lib/features/workout/application/active_workout_provider.dart').readAsStringSync();
    final check = src.indexOf('if (!hasCompletedWorkingSets) return EmptyWorkout();');
    final cancel = src.indexOf('// A zero-working-set attempt should not stop rest');
    expect(check, greaterThan(0));
    expect(cancel, greaterThan(check));
    expect(src, contains('_startRestTimer(remaining, end);'));
  });

  test('summary selects the Home tab rather than only popping routes', () {
    final home = File('lib/features/home/presentation/pages/home_screen.dart').readAsStringSync();
    final sum = File('lib/features/workout/presentation/workout_summary_page.dart').readAsStringSync();
    expect(home, contains('ref.listen<int>(homeTabReturnRequestProvider'));
    expect(sum, contains('homeTabReturnRequestProvider.notifier'));
  });
}
