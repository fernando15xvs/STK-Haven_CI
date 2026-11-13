import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test("Entrenar owns programs, routines, and templates, without today's hero", () {
    final routines = File(
      'lib/features/routines/presentation/pages/routines_page.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/home/presentation/pages/home_screen.dart',
    ).readAsStringSync();
    expect(routines, contains("Text('Entrenar'"));
    expect(routines, contains('MI PROGRAMA'));
    expect(routines, contains('MIS RUTINAS'));
    expect(routines, contains("Text('Plantillas'"));
    expect(routines, contains('QuickTrainingPlanSheet.show(context)'));
    expect(routines, contains('WorkoutLauncher.launch(context, ref, routine)'));
    expect(routines, isNot(contains('TU PRÓXIMA SESIÓN')));
    expect(routines, isNot(contains('SIGUIENTE SESIÓN')));
    expect(shell, isNot(contains("label: 'Programas'")));
    expect(shell, contains("label: 'Entrenar'"));
  });

  test('quick creator needs only routines and weekdays; existing plans remain editable', () {
    final quick = File(
      'lib/features/routines/presentation/widgets/quick_training_plan_sheet.dart',
    ).readAsStringSync();
    expect(quick, contains('routineIds: orderedIds'));
    expect(quick, contains('trainingWeekdays: _weekdays'));
    expect(quick, contains('targetSessionsPerWeek: _weekdays.length'));
    expect(quick, contains('ProgramScheduleMode.continuous'));
    expect(quick, contains('Configuración avanzada'));
    expect(quick, contains('TrainingProgramsPage'));
  });
}
