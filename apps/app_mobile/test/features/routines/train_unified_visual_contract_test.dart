import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekday editor adapts circle widths and exposes semantic labels', () {
    final editor = File(
      'lib/features/routines/presentation/pages/create_routine_page.dart',
    ).readAsStringSync();
    final source = File(
      'lib/features/routines/presentation/widgets/routine_weekday_selector.dart',
    ).readAsStringSync();
    expect(editor, contains('RoutineWeekdaySelector('));
    expect(source, contains('LayoutBuilder('));
    expect(source, contains('constraints.maxWidth'));
    expect(source, contains('Semantics('));
    expect(source, isNot(contains('width: 42,\n                  height: 42,')));
  });

  test('small workouts preserve inputs instead of squeezing previous-set column', () {
    final source = File(
      'lib/features/workout/presentation/active_workout_page_content.dart',
    ).readAsStringSync();
    expect(source, contains('MediaQuery.sizeOf(context).width >= 380'));
    expect(source, contains("Anterior: "));
  });

  test('saved summary closes to Inicio and honors reduced motion', () {
    final source = File(
      'lib/features/workout/presentation/workout_summary_page.dart',
    ).readAsStringSync();
    expect(source, contains("label: 'VOLVER A INICIO'"));
    expect(source, contains('MediaQuery.disableAnimationsOf(context)'));
  });
}
