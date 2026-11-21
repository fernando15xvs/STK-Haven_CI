import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Entrenar uniquely owns next session; Inicio only links to it', () {
    final routines = File(
      'lib/features/routines/presentation/pages/routines_page.dart',
    ).readAsStringSync();
    final hero = File(
      'lib/features/routines/presentation/widgets/next_training_session_hero.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/features/home/presentation/pages/dashboard_page.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/home/presentation/pages/home_screen.dart',
    ).readAsStringSync();
    expect(routines, contains('NextTrainingSessionHero('));
    expect(routines, contains('nextProgramSessionProvider'));
    expect(routines, contains('MIS RUTINAS'));
    expect(routines, contains("label: 'Planificación'"));
    expect(routines, contains("label: 'Administrar'"));
    expect(routines, contains("label: 'Plantillas'"));
    expect(routines, contains('QuickTrainingPlanSheet.show(context)'));
    expect(routines, contains('WorkoutLauncher.launch(context, ref, routine)'));
    expect(hero, contains('SIGUIENTE SESIÓN'));
    expect(hero, contains('activeWorkoutProvider'));
    expect(hero, contains('nextProgramSessionProvider'));
    expect(hero, contains('WorkoutLauncher.launch(context, ref, routine)'));
    expect(hero, contains('const ActiveWorkoutPage()'));
    expect(hero, contains('Rotación flexible · sin día obligatorio'));
    expect(dashboard, contains('home_continue_workout'));
    expect(dashboard, contains('home_open_train'));
    expect(dashboard, isNot(contains('_TodayRoutineCard')));
    expect(dashboard, isNot(contains('SIGUIENTE SESIÓN')));
    expect(shell, contains('void _openTrain() => _selectTab(1)'));
    expect(shell, isNot(contains("label: 'Programas'")));
    expect(shell, contains("label: 'Entrenar'"));
  });

  test('no duplicate Start action for the routine featured in the hero', () {
    final source = File(
      'lib/features/routines/presentation/pages/routines_page.dart',
    ).readAsStringSync();
    expect(source, contains('isSuggested: !workoutActive'));
    expect(source, contains('nextProgramSession?.routine.id ??'));
    expect(source, contains('legacyTodaySession?.routine.id'));
    expect(source, contains('final Widget? start = isSuggested'));
    expect(source, contains('if (start != null)'));
    expect(source, isNot(contains("Text('Plantillas', style: AppTypography.headlineMedium)")));
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
