import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/programs/application/program_routine_order_policy.dart';
import 'package:core/features/programs/application/program_rotation_coordinator.dart';
import 'package:core/features/programs/application/program_week_plan.dart';
import 'package:core/features/programs/application/program_plan_insights.dart';
import 'package:test/test.dart';

void main() {
  final start = DateTime(2026, 11, 23);
  TrainingProgram plan(ProgramSequencePolicy policy, {ProgramScheduleMode mode =
      ProgramScheduleMode.flexible}) => TrainingProgram(id: 'p', name: 'Stoker',
    routineIds: ['A','B','C','D'], createdAt: start, startedAt: start,
    sequencePolicy: policy, scheduleMode: mode, targetSessionsPerWeek: 5,
    weeklySequenceRoutineIds: ['A','B','C','D','A'], trainingWeekdays: {1,2,4,5,6});
  ProgramWeekPlan view(TrainingProgram p, DateTime now) =>
      ProgramWeekPlan.calculate(program: p, routines: const [], now: now);
  test('five distinct slots without invented dates; next week rolls or repeats', () {
    for (final policy in ProgramSequencePolicy.values) {
      final p = plan(policy);
      final first = view(p, DateTime(2026,11,23,8));
      expect(first.slots.map((s) => s.routineId), ['A','B','C','D','A']);
      expect(first.slots.map((s) => s.id).toSet().length, 5);
      expect(first.slots.every((s) => s.date == null), isTrue);
      expect(first.nextWeekRoutineIds, policy == ProgramSequencePolicy.rolling
          ? ['B','C','D','A','B'] : ['A','B','C','D','A']);
      expect(first.nextSuggestion!.date, isNull);
    }
  });
  test('completed snapshots and actual pointer survive absence and routine reorder', () {
    final p = plan(ProgramSequencePolicy.rolling).recordCompletion(
      workoutSessionId: 'a', routineId: 'A', completedAt: DateTime(2026,11,23,18));
    final edited = ProgramRoutineOrderPolicy.applyScheduleEdit(existing: p,
      edited: p.copyWith(routineIds: ['D','B','C','A']), now: DateTime(2026,11,25));
    expect(edited.nextRoutineId, 'B');
    expect(edited.completions.single.routineId, 'A');
    final week = view(edited, DateTime(2026,11,25,9));
    expect(week.slots.first.isCompleted, isTrue);
    expect(week.slots[1].routineId, 'B');
    expect(week.nextSuggestion!.routineId, 'B');
    expect(ProgramPlanInsights.calculate(program: edited, routines: const [],
        now: DateTime(2026,11,25,9)).nextScheduledRoutineId, 'B');
  });
  test('mode changes preserve old completions and reject retroactive replay', () {
    final p = plan(ProgramSequencePolicy.rolling).recordCompletion(
      workoutSessionId: 'a', routineId: 'A', completedAt: DateTime(2026,11,23,18));
    final changed = ProgramRoutineOrderPolicy.applyScheduleEdit(existing: p,
      edited: p.copyWith(sequencePolicy: ProgramSequencePolicy.weekly),
      now: DateTime(2026,11,25,8));
    final old = WorkoutSession(id: 'old-b', routineId: 'B', routineNameSnapshot: 'B',
      startedAt: DateTime(2026,11,24,8), finishedAt: DateTime(2026,11,24,9),
      durationSeconds: 3600, exercises: [WorkoutExercise(exerciseId: 'x',
        exerciseNameSnapshot: 'X', muscleGroupSnapshot: 'Torso',
        sets: [WorkoutSet(weight: 10, reps: 8, completed: true)])]);
    final replayed = ProgramRotationCoordinator.reconcile(changed, [old]);
    expect(replayed.completions.length, 1);
    expect(replayed.nextRoutineIdAt(DateTime(2026,11,25,9)), 'B');
    expect(replayed.startedAt, start);
    expect(replayed.nextRotationIndex, p.nextRotationIndex);
  });
  test('invalid newly authored weekly sequences are rejected; repeated IDs allowed', () {
    final p = plan(ProgramSequencePolicy.weekly);
    ProgramRoutineOrderPolicy.validateWeeklyConfiguration(p);
    expect(() => ProgramRoutineOrderPolicy.validateWeeklyConfiguration(
      p.copyWith(weeklySequenceRoutineIds: ['A','B'])), throwsArgumentError);
    expect(() => ProgramRoutineOrderPolicy.validateWeeklyConfiguration(
      p.copyWith(weeklySequenceRoutineIds: ['A','B','C','D','missing'])), throwsArgumentError);
    expect(() => ProgramRoutineOrderPolicy.validateWeeklyConfiguration(
      p.copyWith(routineIds: ['A','A','B','C','D'])), throwsArgumentError);
  });
  test('continuous keeps next pending routine at next opportunity, fixed keeps dates', () {
    final p = plan(ProgramSequencePolicy.weekly, mode: ProgramScheduleMode.continuous);
    final w = view(p, DateTime(2026,11,25,8));
    expect(w.nextSuggestion!.routineId, 'A');
    expect(w.nextSuggestion!.date, DateTime(2026,11,26));
    final fixed = p.copyWith(scheduleMode: ProgramScheduleMode.fixed,
        fixedWeekdayRoutineIds: {1:'D',4:'B'});
    final f = view(fixed, DateTime(2026,11,25,8));
    expect(f.slots.map((s) => s.routineId), ['D','B']);
    expect(f.nextSuggestion!.routineId, 'B');
    expect(f.nextSuggestion!.date, DateTime(2026,11,26));
  });
  test('calendar boundaries use civil day arithmetic', () {
    expect(TrainingProgram.localWeekStart(DateTime(2026,12,1)), DateTime(2026,11,30));
    expect(TrainingProgram.shiftCalendarDays(DateTime(2026,12,31), 1), DateTime(2027,1,1));
  });
}
