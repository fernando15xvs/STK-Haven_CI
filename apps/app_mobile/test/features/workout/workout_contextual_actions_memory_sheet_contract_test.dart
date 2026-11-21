import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exercise secondary actions stay available without crowding set entry', () {
    final source = File(
      'lib/features/workout/presentation/active_workout_page_content.dart',
    ).readAsStringSync();

    final options = source.indexOf("key: ValueKey('workout_exercise_options_");
    final setHeader = source.indexOf("Text('SERIE'");
    expect(options, greaterThan(0));
    expect(setHeader, greaterThan(options));
    expect(source, contains("tooltip: 'Opciones del ejercicio'"));
    for (final action in ['technique', 'note', 'replace', 'unilateral']) {
      expect(source, contains("value: '$action'"));
    }
    expect(source, contains("label: 'Técnica y ficha'"));
    expect(source, contains('ExerciseDetailPage(exercise: item)'));
    expect(source, contains('ref.read(exerciseListProvider)'));
    expect(source, contains("label: 'Nota rápida'"));
    expect(source, contains("label: 'Sustituir ejercicio'"));
    expect(source, contains("'Configurar unilateral'"));
    expect(source, contains('class _WorkoutExerciseActionLabel'));
    expect(source, contains('width: 208'));
    expect(source, contains('maxLines: 3'));
    expect(source, contains("key: ValueKey('workout_exercise_guidance_"));
    expect(source, contains('_showGuidance = !_showGuidance'));
    expect(source, contains('if (_showGuidance) ...['));
    expect(source, contains("Text('Añadir serie')"));
    expect(source, contains("tooltip: 'Acciones de la serie'"));
    expect(source, contains("label: 'Finalizar entrenamiento'"));
  });

  test('memory is contextual, never a floating obstruction', () {
    final page = File(
      'lib/features/workout/presentation/active_workout_page_content.dart',
    ).readAsStringSync();
    final memory = File(
      '../../packages/core/lib/features/workout/presentation/widgets/'
      'active_workout_memory_overlay.dart',
    ).readAsStringSync();

    expect(page, contains('ActiveWorkoutMemoryAccess.maybeOf(context)'));
    expect(page, contains("tooltip: 'Memoria del ejercicio'"));
    expect(page, contains('memoryAccess.openForExercise('));
    expect(page, contains('widget.workoutExercise.instanceId'));
    expect(memory, contains('class ActiveWorkoutMemoryAccess extends InheritedWidget'));
    expect(memory, contains('return ActiveWorkoutMemoryAccess('));
    expect(memory, contains('requestedInstanceId'));
    expect(memory, contains('item.instanceId == requestedInstanceId'));
    expect(memory, contains('showModalBottomSheet<void>('));
    expect(memory, contains('useSafeArea: true'));
    expect(memory, contains('isScrollControlled: true'));
    expect(memory, contains('showDragHandle: true'));
    expect(memory, contains("tooltip: 'Cerrar memoria'"));
    expect(memory, contains('onRefresh?.call()'));
    expect(memory, isNot(contains("key: const ValueKey('memory_launcher')")));
    expect(memory, isNot(contains('Positioned(')));
  });

  test('set actions share the row and leave previous performance visible', () {
    final src = File(
      'lib/features/workout/presentation/active_workout_page_content.dart',
    ).readAsStringSync();
    final row = src.substring(src.indexOf('class _SetRowState'),
        src.indexOf('class _SideButton'));
    expect(row, contains("'Completar serie'"));
    expect(row, contains("tooltip: 'Acciones de la serie'"));
    expect(row, contains('if (MediaQuery.sizeOf(context).width < 460'));
    expect(row, contains("Text('Eliminar serie')"));
    expect(row, isNot(contains("Text('Acciones')")));
    expect(src, contains('showRirColumn: settings.isRirEnabled'));
    expect(src, contains("Text('SERIE'"));
  });
}
