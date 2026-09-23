import 'package:core/features/routines/application/routine_template_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Routine templates', () {
    test('catalog exposes unique templates with exercises', () {
      final templates = buildRoutineTemplates();
      final ids = templates.map((template) => template.id).toSet();

      expect(templates, isNotEmpty);
      expect(ids.length, templates.length);
      expect(templates.every((template) => template.exercises.isNotEmpty), true);
      expect(templates.every((template) => template.suggestedDays.isNotEmpty), true);
    });

    test('template exercise configuration is valid', () {
      final templates = buildRoutineTemplates();

      for (final template in templates) {
        for (final exercise in template.exercises) {
          expect(exercise.exerciseId, isNotEmpty);
          expect(exercise.targetSets, greaterThan(0));
          expect(exercise.targetRepsMin, greaterThan(0));
          expect(exercise.targetRepsMax, greaterThanOrEqualTo(exercise.targetRepsMin));
          expect(exercise.restSeconds, greaterThan(0));
        }
      }
    });
  });
}
