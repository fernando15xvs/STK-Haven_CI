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

  test('compact memory uses a dismissible sheet and hides with the keyboard', () {
    final source = File(
      '../../packages/core/lib/features/workout/presentation/widgets/'
      'active_workout_memory_overlay.dart',
    ).readAsStringSync();

    expect(source, contains('showModalBottomSheet<void>('));
    expect(source, contains('useSafeArea: true'));
    expect(source, contains('isScrollControlled: true'));
    expect(source, contains('showDragHandle: true'));
    expect(source, contains("tooltip: 'Cerrar memoria'"));
    expect(source, contains("key: const ValueKey('memory_launcher')"));
    expect(source, contains('onTap: _openCompactMemory'));
    expect(source, contains('MediaQuery.viewInsetsOf(context).bottom > 0'));
    expect(source, contains('if (!keyboardOpen)'));
    expect(source, isNot(contains('_compactExpanded')));
    expect(source, contains('onRefresh?.call()'));
  });
}
