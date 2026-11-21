import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_routine_order_policy.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 1);
  TrainingProgram program({
    List<String> ids = const ['A', 'B', 'C'],
    int nextIndex = 1,
    List<ProgramCompletion> completions = const [],
  }) => TrainingProgram(
    id: 'existing-plan',
    name: 'Entrenamiento actual',
    routineIds: ids,
    createdAt: start,
    startedAt: start,
    nextRotationIndex: nextIndex,
    completions: completions,
  );

  test('reordering never changes which existing routine is next', () {
    final original = program();
    final newOrder = ['B', 'C', 'A'];

    final index = ProgramRoutineOrderPolicy.nextIndexAfterEdit(
      existing: original,
      updatedRoutineIds: newOrder,
    );

    expect(index, 0);
    expect(original.copyWith(
      routineIds: newOrder, nextRotationIndex: index,
    ).nextRoutineId, 'B');
    expect(original.routineIds, ['A', 'B', 'C']);
  });

  test('removing next routine moves to next survivor in old cycle', () {
    final index = ProgramRoutineOrderPolicy.nextIndexAfterEdit(
      existing: program(),
      updatedRoutineIds: ['C', 'A'],
    );
    expect(index, 0); // B removed, C is the next surviving slot.
  });

  test('fresh unrelated routine list starts at the first entry', () {
    final index = ProgramRoutineOrderPolicy.nextIndexAfterEdit(
      existing: program(),
      updatedRoutineIds: ['X', 'Y'],
    );
    expect(index, 0);
  });

  test('an empty edited list never creates an invalid index', () {
    expect(ProgramRoutineOrderPolicy.nextIndexAfterEdit(
      existing: program(),
      updatedRoutineIds: const [],
    ), 0);
  });

  test('future scheduling follows saved next identity after reorder', () {
    final completion = ProgramCompletion(
      workoutSessionId: 'saved-a',
      routineId: 'A',
      completedAt: start.add(const Duration(days: 2)),
      rotationIndex: 0, // Historical: A was index 0 at completion time.
      programWeek: 1,
    );
    final original = program(completions: [completion]);
    final editedOrder = ['B', 'C', 'A'];
    final next = ProgramRoutineOrderPolicy.nextIndexAfterEdit(
      existing: original,
      updatedRoutineIds: editedOrder,
    );
    final edited = original.copyWith(
      routineIds: editedOrder,
      nextRotationIndex: next,
    );

    final projectedIndex = ProgramScheduleProjector.rotationIndexAt(
      edited,
      start.add(const Duration(days: 4)),
    );

    expect(projectedIndex, 0); // B, not C from stale old index.
    expect(edited.routineIds[projectedIndex], 'B');
    expect(edited.completions.single.rotationIndex, 0);
    expect(edited.completions.single.routineId, 'A');
  });

  test('fixed schedule stays independent from the rotation pointer', () {
    final fixed = program().copyWith(
      scheduleMode: ProgramScheduleMode.fixed,
      fixedWeekdayRoutineIds: const {DateTime.monday: 'C'},
    );
    final index = ProgramRoutineOrderPolicy.nextIndexAfterEdit(
      existing: fixed,
      updatedRoutineIds: const ['C', 'B', 'A'],
    );
    expect(index, 1);
  });
}
