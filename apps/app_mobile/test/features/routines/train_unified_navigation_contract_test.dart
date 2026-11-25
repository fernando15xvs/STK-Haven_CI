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
    expect(routines, contains("Text('Mis rutinas'"));
    expect(routines, isNot(contains("Text('Entrenar'")));
    expect(routines, contains("tooltip: 'Planificación'"));
    expect(routines, contains("label: 'Gestionar programa'"));
    expect(routines, contains("label: 'Biblioteca de ejercicios'"));
    expect(routines, contains("title: const Text('Administrar')"));
    expect(routines, contains("title: const Text('Plantillas de rutinas')"));
    expect(routines, contains("title: const Text('Plantillas de programas')"));
    expect(routines, contains('QuickTrainingPlanSheet.show(context)'));
    expect(routines, contains('WorkoutLauncher.launch(context, ref, routine)'));
    expect(hero, contains('INICIAR SESIÓN'));
    expect(hero, contains('activeWorkoutProvider'));
    expect(hero, contains('activeWorkoutProvider.select((state) => state.session)'));
    expect(hero, contains('activeWorkoutLastActivityProvider'));
    expect(hero, contains('nextProgramSessionProvider'));
    expect(hero, contains('WorkoutLauncher.launch(context, ref, routine)'));
    expect(hero, contains('const ActiveWorkoutPage()'));
    final scheduleLabel = File(
      'lib/features/routines/application/next_training_session_label.dart',
    ).readAsStringSync();
    expect(hero, contains('TrainingDayDecision.resolve('));
    expect(scheduleLabel, contains('Rotación flexible · sin día obligatorio'));
    final homeShortcut = File(
      'lib/features/home/presentation/widgets/home_training_shortcut.dart',
    ).readAsStringSync();
    expect(dashboard, contains('HomeTrainingShortcut('));
    expect(homeShortcut, contains('home_continue_workout'));
    expect(dashboard, isNot(contains('home_open_train')));
    expect(dashboard, isNot(contains('_TodayRoutineCard')));
    expect(dashboard, isNot(contains('SIGUIENTE SESIÓN')));
    expect(shell, isNot(contains('void _openTrain()')));
    expect(shell, isNot(contains("label: 'Programas'")));
    expect(shell, contains("label: 'Entrenar'"));
  });

  test('no duplicate Start action for the routine featured in the hero', () {
    final source = File(
      'lib/features/routines/presentation/pages/routines_page.dart',
    ).readAsStringSync();
    expect(source, contains('final featuredRoutineId = day.featuredRoutineId'));
    expect(source, contains('routine.id != featuredRoutineId'));
    expect(source, contains('eligibleRoutines.take(3)'));
    expect(source, contains('final hasHiddenRoutines ='));
    expect(source, contains('_showAllRoutines'));
    expect(source, contains("ValueKey('train_show_all_routines')"));
    expect(source, contains('allowStart: !workoutActive'));
    expect(source, contains('if (allowStart)'));
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
