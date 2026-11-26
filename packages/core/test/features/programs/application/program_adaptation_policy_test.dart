import 'package:core/domain/models/program_adaptation.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/programs/application/program_adaptation_policy.dart';
import 'package:core/features/programs/application/program_rotation_coordinator.dart';
import 'package:core/features/programs/application/program_routine_order_policy.dart';
import 'package:core/features/programs/application/program_week_plan.dart';
import 'package:test/test.dart';

void main() {
  final monday = DateTime(2026,11,23);
  final now = DateTime(2026,11,25,9);
  TrainingProgram plan({ProgramScheduleMode mode = ProgramScheduleMode.flexible,
      ProgramSequencePolicy sequence = ProgramSequencePolicy.rolling}) => TrainingProgram(
    id: 'p', name: 'STK', routineIds: ['A','B','C','D'], createdAt: monday, startedAt: monday,
    scheduleMode: mode, sequencePolicy: sequence, targetSessionsPerWeek: 5,
    weeklySequenceRoutineIds: ['A','B','C','D','A'], trainingWeekdays: {1,2,3,4,5},
    fixedWeekdayRoutineIds: {1:'A',2:'B',3:'C',4:'D',5:'A'});
  TrainingProgram prepared(TrainingProgram p) => ProgramAdaptationPolicy.prepare(p, const [], now);
  List<PlanOccurrence> slots(TrainingProgram p) => ProgramAdaptationPolicy.current(p);
  ProgramWeekPlan view(TrainingProgram p, DateTime time) =>
      ProgramWeekPlan.calculate(program: p, routines: const [], now: time);
  WorkoutSession workout(String id, String routine, {bool complete = true}) => WorkoutSession(
    id: id, routineId: routine, routineNameSnapshot: routine,
    startedAt: now, finishedAt: now.add(const Duration(hours: 1)), durationSeconds: 3600,
    exercises: [WorkoutExercise(exerciseId: 'e', exerciseNameSnapshot: 'E',
      muscleGroupSnapshot: 'Torso', sets: [WorkoutSet(weight: 10, reps: 8, completed: complete)])]);

  test('omission does not create completion and repeated routines have distinct identities', () {
    final p = prepared(plan());
    expect(slots(p).map((o) => o.id).toSet().length, 5);
    final skipped = ProgramAdaptationPolicy.omit(p, const [], slots(p).first.id, now);
    expect(skipped.completions, isEmpty);
    expect(view(skipped, now).nextSuggestion!.routineId, 'B');
    final restored = ProgramAdaptationPolicy.restoreOmitted(skipped, const [], slots(p).first.id, now);
    expect(view(restored, now).nextSuggestion!.routineId, 'A');
  });

  test('postpone and exchange do not edit the routine template', () {
    final p = prepared(plan());
    final postponed = ProgramAdaptationPolicy.postpone(p, const [], slots(p)[0].id,
        now, DateTime(2026,11,26));
    expect(view(postponed, now).nextSuggestion!.routineId, 'B');
    final exchanged = ProgramAdaptationPolicy.exchange(p, const [], slots(p)[0].id, slots(p)[2].id, now);
    expect(view(exchanged, now).nextSuggestion!.routineId, 'C');
    expect(exchanged.routineIds, p.routineIds);
  });

  test('fixed missed session can be recovered without changing template', () {
    final p = prepared(plan(mode: ProgramScheduleMode.fixed));
    expect(view(p, now).nextSuggestion!.routineId, 'C');
    final missed = slots(p).firstWhere((o) => o.routineId == 'B');
    final recovered = ProgramAdaptationPolicy.recover(p, const [], missed.id, now, shiftFollowing: true);
    expect(view(recovered, now).nextSuggestion!.routineId, 'B');
    expect(recovered.fixedWeekdayRoutineIds, p.fixedWeekdayRoutineIds);
    expect(slots(recovered).firstWhere((o) => o.routineId == 'C').date, DateTime(2026,11,26));
  });

  test('pause lower routines and resume without deleting or inventing sessions', () {
    final p = prepared(plan());
    final paused = ProgramAdaptationPolicy.pause(p, const [], now, routineIds: {'A','C'});
    expect(view(paused, now).nextSuggestion!.routineId, 'B');
    expect(view(paused, now).slots.where((s) => s.isPaused).length, 3);
    final resumed = ProgramAdaptationPolicy.resume(paused, now.add(const Duration(hours: 1)),
        routineIds: {'A','C'});
    expect(view(resumed, now.add(const Duration(hours: 2))).nextSuggestion!.routineId, 'A');
    expect(resumed.routineIds, p.routineIds);
  });

  test('whole program pause freezes elapsed duration and resumes automatically at end', () {
    final p = ProgramAdaptationPolicy.pause(plan(), const [], monday,
        until: DateTime(2026,11,30));
    expect(view(p, now).isPaused, isTrue);
    expect(view(p, now).nextSuggestion, isNull);
    expect(p.weekAt(DateTime(2026,11,30)), 1);
    expect(p.weekAt(DateTime(2026,12,7)), 2);
    expect(view(p, DateTime(2026,11,30,9)).isPaused, isFalse);
    expect(view(p, DateTime(2026,11,30,9)).nextSuggestion, isNotNull);
  });

  test('bound workout advances only its occurrence; independent and partial do not count', () {
    var p = prepared(plan());
    final first = slots(p).first;
    p = ProgramAdaptationPolicy.bind(p, const [], 'free', 'A', now, independent: true);
    p = ProgramAdaptationPolicy.bind(p, const [], 'bound', 'A', now, slotId: first.id);
    final partial = ProgramRotationCoordinator.reconcile(p, [workout('free','A'), workout('bound','A',complete:false)]);
    expect(partial.completions, isEmpty);
    final completed = ProgramRotationCoordinator.reconcile(partial, [workout('free','A'),workout('bound','A')]);
    expect(completed.completions.single.workoutSessionId, 'bound');
    expect(slots(completed).first.status, PlanOccurrenceStatus.completed);
    expect(ProgramRotationCoordinator.reconcile(completed, [workout('bound','A')]).completions.length, 1);
    final restored = TrainingProgram.fromJson(completed.toJson());
    expect(restored.adaptation!.bindings['free'], '');
    expect(restored.adaptation!.occurrences.first.workoutId, 'bound');
    expect(restored.duplicate(newId:'copy',newName:'Copy',now:now).adaptation,isNull);
  });

  test('change mode during pause preserves restrictions and archives future slots', () {
    final paused = ProgramAdaptationPolicy.pause(plan(), const [], now, routineIds: {'A'});
    final edited = ProgramRoutineOrderPolicy.applyScheduleEdit(existing: paused,
      edited: paused.copyWith(sequencePolicy: ProgramSequencePolicy.weekly), now: now);
    expect(edited.adaptation!.routinePausedAt('A', now), isTrue);
    expect(slots(edited).length, 5);
    expect(slots(edited).map((o) => o.id).toSet().intersection(slots(paused).map((o) => o.id).toSet()), isEmpty);
    expect(view(edited, now).nextSuggestion!.routineId, 'B');
    expect(edited.adaptation!.occurrences.where((o) => o.archived).length, 5);
  });

  test('template preview repeats positions or rolls and normalizes removed routines', () {
    const catalog = ['A','B','C','D'];
    expect(ProgramRoutineOrderPolicy.previewWeeks(catalog, ['A','B','C','D','A'], 5, ProgramSequencePolicy.weekly),
      [['A','B','C','D','A'],['A','B','C','D','A']]);
    expect(ProgramRoutineOrderPolicy.previewWeeks(catalog, [], 5, ProgramSequencePolicy.rolling),
      [['A','B','C','D','A'],['B','C','D','A','B']]);
    expect(ProgramRoutineOrderPolicy.normalizeWeeklySlots(['A','B'], ['A','deleted','A'], 4), ['A','A','A','B']);
  });

  test('explicit previous-week recovery replaces a pending slot without fake completion', () {
    final first = prepared(plan(sequence: ProgramSequencePolicy.weekly));
    final nextMonday = DateTime(2026,11,30,9);
    final second = ProgramAdaptationPolicy.prepare(first, const [], nextMonday);
    final old = slots(first)[1];
    final replace = slots(second).first;
    final recovered = ProgramAdaptationPolicy.recoverPrevious(second, const [], old.id, replace.id, nextMonday);
    expect(recovered.completions, isEmpty);
    expect(slots(recovered).first.id, old.id);
    expect(slots(recovered).first.routineId, 'B');
    expect(slots(recovered).firstWhere((o) => o.id == replace.id).status, PlanOccurrenceStatus.omitted);
    expect(recovered.adaptation!.occurrences.map((o) => o.id).toSet().length,
        recovered.adaptation!.occurrences.length);
  });

  test('allocation cursor remains separate from next pending occurrence', () {
    var p = prepared(plan());
    expect(p.nextRoutineId, 'A');
    expect(p.adaptation!.nextUnallocatedRotationIndex, 1);
    final first = slots(p).first;
    p = ProgramAdaptationPolicy.bind(p, const [], 'real', 'A', now, slotId: first.id);
    p = ProgramRotationCoordinator.reconcile(p, [workout('real','A')]);
    expect(p.nextRoutineId, 'B');
    expect(p.adaptation!.nextUnallocatedRotationIndex, 1);
    p = TrainingProgram.fromJson(p.toJson());
    final next = ProgramAdaptationPolicy.prepare(p, const [], DateTime(2026,11,30,9));
    expect(slots(next).map((o) => o.routineId), ['B','C','D','A','B']);
    expect(next.nextRoutineId, 'B');
  });

  test('continuous forecast uses distinct remaining opportunity days', () {
    final thursday = DateTime(2026,11,26,9);
    final p = ProgramAdaptationPolicy.prepare(plan(mode: ProgramScheduleMode.continuous)
      .copyWith(trainingWeekdays: {1,2,4,5,6}), const [], thursday);
    final dates = ProgramAdaptationPolicy.projectedDates(p, const [], thursday);
    expect(dates.values.toList(), [DateTime(2026,11,26),DateTime(2026,11,27),DateTime(2026,11,28)]);
    expect(view(p,thursday).nextWeekRoutineIds, ['D','A','B','C','D']);
  });

  test('legacy cursor repairs from trusted completion without rewriting history', () {
    final p = plan().recordCompletion(workoutSessionId:'old',routineId:'A',completedAt:now)
      .copyWith(nextRotationIndex:0);
    final repaired = ProgramRotationCoordinator.reconcile(p, const []);
    expect(repaired.nextRoutineId,'B');
    expect(repaired.completions,p.completions);
  });

  test('rollover retains only bounded rolling debt and weekly starts again', () {
    final nextMonday = DateTime(2026,11,30,9);
    final rolling = prepared(plan());
    final next = ProgramAdaptationPolicy.prepare(rolling, const [], nextMonday);
    expect(slots(next).length, 5);
    expect(slots(next).first.id, slots(rolling).first.id);
    final weekly = prepared(plan(sequence: ProgramSequencePolicy.weekly));
    final nextWeekly = ProgramAdaptationPolicy.prepare(weekly, const [], nextMonday);
    expect(slots(nextWeekly).map((o) => o.routineId), ['A','B','C','D','A']);
    expect(slots(nextWeekly).first.id, isNot(slots(weekly).first.id));
  });
}
