import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final monday = DateTime(2026, 11, 9);
  Routine routine(String id, int day) => Routine(
    id: id, name: id, scheduledDays: [day],
    exercises: const [], createdAt: monday,
  );
  final routines = [routine('a', DateTime.saturday), routine('b', DateTime.sunday)];
  TrainingProgram plan(ProgramScheduleMode mode, {
    Set<int> weekdays = const {},
    Map<int, String> fixed = const {},
  }) => TrainingProgram(
    id: 'plan', name: 'Entrenamiento', routineIds: const ['a', 'b'],
    createdAt: monday, startedAt: monday, scheduleMode: mode,
    trainingWeekdays: weekdays, fixedWeekdayRoutineIds: fixed,
    targetSessionsPerWeek: 2,
  );

  test('fixed program schedule overrides optional routine days', () {
    final items = ProgramScheduleProjector.projectWeek(
      program: plan(ProgramScheduleMode.fixed, fixed: const {DateTime.monday: 'b'}),
      routines: routines, weekStart: monday,
    );
    expect(items.map((s) => s.date.weekday).toList(), [DateTime.monday]);
    expect(items.map((s) => s.routineId).toList(), ['b']);
  });

  test('continuous program weekdays override optional routine weekdays', () {
    final items = ProgramScheduleProjector.projectWeek(
      program: plan(ProgramScheduleMode.continuous,
          weekdays: const {DateTime.monday, DateTime.thursday}),
      routines: routines, weekStart: monday,
    );
    expect(items.map((s) => s.date.weekday).toList(),
        [DateTime.monday, DateTime.thursday]);
  });

  test('flexible program days are estimates, not obligations', () {
    final items = ProgramScheduleProjector.projectWeek(
      program: plan(ProgramScheduleMode.flexible),
      routines: routines, weekStart: monday,
    );
    expect(items, isNotEmpty);
    expect(items.every((item) => item.isFlexibleEstimate), isTrue);
  });
}
