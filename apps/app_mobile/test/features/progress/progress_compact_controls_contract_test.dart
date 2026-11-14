import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('analytics tabs own compact shared period, not the four tab labels', () {
    final root = File('lib/features/progress/presentation/pages/progress_page.dart').readAsStringSync();
    final muscle = File('lib/features/progress/presentation/widgets/muscle_heatmap_grid.dart').readAsStringSync();
    // Only the four navigation names belong inside the TabBar.
    for (final label in ['Resumen', 'Ejercicios', 'Músculos', 'Medidas']) {
      expect(root, contains("Tab(text: '$label')"));
    }
    expect(root, isNot(contains('const ProgressSharedPeriodSelector()')));
    expect(root, contains('const CompactProgressPeriodSelector()'));
    expect(muscle, contains('child: CompactProgressPeriodSelector()'));
    expect(muscle, isNot(contains('El período se cambia arriba')));
  });

  test('focused performance retains period independent of main tabs', () {
    final route = File('lib/features/progress/presentation/pages/focused_exercise_progress_page.dart').readAsStringSync();
    expect(route, contains('initialExerciseId: exercise.id'));
    expect(route, isNot(contains('useSharedPeriod: true')));
  });
}
