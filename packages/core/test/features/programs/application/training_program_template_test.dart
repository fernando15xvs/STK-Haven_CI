import 'package:core/domain/models/training_program.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 26, 10);

  TrainingProgram program() => TrainingProgram(
        id: 'p1',
        name: 'Upper Lower',
        routineIds: const ['ua', 'la', 'ub', 'lb'],
        createdAt: now,
        startedAt: now,
        durationWeeks: 8,
        nextRotationIndex: 2,
        completions: [
          ProgramCompletion(
            workoutSessionId: 's1',
            routineId: 'ua',
            completedAt: now,
            rotationIndex: 0,
            programWeek: 1,
          ),
        ],
      );

  test('legacy JSON defaults to a normal program', () {
    final json = program().toJson()..remove('isTemplate');
    final restored = TrainingProgram.fromJson(json);
    expect(restored.isTemplate, isFalse);
  });

  test('saving as template resets mutable rotation and history', () {
    final template = program().toTemplate(
      newId: 't1',
      newName: 'Upper Lower · plantilla',
      now: now.add(const Duration(hours: 1)),
    );

    expect(template.isTemplate, isTrue);
    expect(template.isActive, isFalse);
    expect(template.nextRotationIndex, 0);
    expect(template.completions, isEmpty);
    expect(template.routineIds, program().routineIds);
  });

  test('instantiating a template creates independent fresh program state', () {
    final template = program().toTemplate(
      newId: 't1',
      newName: 'Plantilla',
      now: now,
    );
    final instance = template.instantiateTemplate(
      newId: 'p2',
      newName: 'Cliente A',
      now: now.add(const Duration(days: 1)),
    );

    expect(instance.isTemplate, isFalse);
    expect(instance.isActive, isFalse);
    expect(instance.nextRotationIndex, 0);
    expect(instance.completions, isEmpty);
    expect(instance.id, isNot(template.id));
  });

  test('pause and resume flags do not change rotation or completions', () {
    final original = program();
    final paused = original.copyWith(isActive: false);
    final resumed = paused.copyWith(isActive: true);

    expect(resumed.nextRotationIndex, original.nextRotationIndex);
    expect(resumed.completions.length, original.completions.length);
    expect(resumed.nextRoutineId, original.nextRoutineId);
  });

  test('changing training days does not change rotation position', () {
    final original = program();
    final changed = original.copyWith(
      trainingWeekdays: const <int>{1, 3, 5},
    );

    expect(changed.nextRotationIndex, original.nextRotationIndex);
    expect(changed.nextRoutineId, original.nextRoutineId);
    expect(changed.completions.length, original.completions.length);
  });

  test('deload configuration never changes routine order or next slot', () {
    final original = program();
    final deload = original.copyWith(deloadWeeks: const <int>{2, 4});

    expect(deload.routineIds, original.routineIds);
    expect(deload.nextRotationIndex, original.nextRotationIndex);
    expect(deload.nextRoutineId, original.nextRoutineId);
  });

  test('json backup restore preserves exact rotation state', () {
    final original = program().copyWith(
      trainingWeekdays: const <int>{1, 2, 4, 5, 6},
      deloadWeeks: const <int>{4},
    );

    final restored = TrainingProgram.fromJson(original.toJson());

    expect(restored.nextRotationIndex, original.nextRotationIndex);
    expect(restored.nextRoutineId, original.nextRoutineId);
    expect(restored.routineIds, original.routineIds);
    expect(restored.trainingWeekdays, original.trainingWeekdays);
    expect(restored.deloadWeeks, original.deloadWeeks);
    expect(
      restored.completions.map((value) => value.workoutSessionId),
      original.completions.map((value) => value.workoutSessionId),
    );
  });

  test('template cannot instantiate from a normal program', () {
    expect(
      () => program().instantiateTemplate(
        newId: 'bad',
        newName: 'bad',
        now: now,
      ),
      throwsStateError,
    );
  });
}
