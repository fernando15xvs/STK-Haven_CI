import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:core/features/programs/application/program_rotation_coordinator.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:test/test.dart';

void main() {
  final monday = DateTime(2026, 11, 23);
  TrainingProgram plan({ProgramSequencePolicy policy = ProgramSequencePolicy.weekly,
      ProgramScheduleMode mode = ProgramScheduleMode.flexible}) => TrainingProgram(
    id: 'p', name: 'Stoker', routineIds: const ['A', 'B', 'C', 'D'],
    createdAt: monday, startedAt: monday, scheduleMode: mode,
    targetSessionsPerWeek: 5, sequencePolicy: policy,
    weeklySequenceRoutineIds: const ['A', 'B', 'C', 'D', 'A'],
    trainingWeekdays: const {1, 2, 4, 5, 6},
  );
  List<String> projection(TrainingProgram p) => ProgramScheduleProjector.project(
      program: p, routines: const [], from: monday, days: 14)
      .map((s) => s.routineId).toList();

  test('five slots repeat each week or roll across weeks independently of days', () {
    for (final mode in [ProgramScheduleMode.flexible, ProgramScheduleMode.continuous]) {
      expect(projection(plan(mode: mode)),
          ['A','B','C','D','A','A','B','C','D','A']);
      expect(projection(plan(mode: mode, policy: ProgramSequencePolicy.rolling)),
          ['A','B','C','D','A','B','C','D','A','B']);
    }
  });

  test('weekly sequence resets after a missed week and does not consume extra slots', () {
    var p = plan();
    p = p.recordCompletion(workoutSessionId: '1', routineId: 'A',
        completedAt: monday.add(const Duration(hours: 12)));
    expect(p.nextRoutineIdAt(DateTime(2026,11,25)), 'B');
    expect(p.nextRoutineIdAt(DateTime(2026,11,30)), 'A');
    final wrong = p.recordCompletion(workoutSessionId: 'wrong', routineId: 'C',
        completedAt: DateTime(2026,11,25,12));
    expect(wrong.completions.length, 1);
    for (final (i,id) in ['B','C','D','A'].indexed) {
      p = p.recordCompletion(workoutSessionId: 's$i', routineId: id,
          completedAt: DateTime(2026,11,24+i,12));
    }
    expect(p.completions.length, 5);
    expect(p.nextRoutineIdAt(DateTime(2026,11,28)), isNull);
    expect(p.nextRoutineIdAt(DateTime(2026,11,30)), 'A');
    expect(p.nextRotationIndex, 0);
    expect(p.recordCompletion(workoutSessionId: 'extra', routineId: 'A',
        completedAt: DateTime(2026,11,29,12)).completions.length, 5);
  });

  test('weekly replay respects distinct slots and is idempotent', () {
    WorkoutSession session(String id, String routine, DateTime date) => WorkoutSession(
      id: id, routineId: routine, routineNameSnapshot: routine,
      startedAt: date, finishedAt: date.add(const Duration(hours: 1)),
      exercises: [WorkoutExercise(exerciseId: 'exercise',
        sets: [WorkoutSet(weight: 10, reps: 8, completed: true)])],
      durationSeconds: 3600,
    );
    final history = [
      session('a1','A', DateTime(2026,11,23,8)),
      session('b1','B', DateTime(2026,11,25,8)),
      session('a2','A', DateTime(2026,11,30,8)),
    ];
    final p = ProgramRotationCoordinator.reconcile(plan(), history);
    expect(p.completions.map((c) => c.rotationIndex), [0,1,0]);
    expect(ProgramRotationCoordinator.reconcile(p, history).completions.length, 3);
  });

  test('old payload remains rolling; repeated slots survive JSON, copy and template', () {
    final original = plan();
    final old = original.toJson()..remove('sequencePolicy')..remove('weeklySequenceRoutineIds');
    expect(TrainingProgram.fromJson(old).sequencePolicy, ProgramSequencePolicy.rolling);
    final restored = TrainingProgram.fromJson(original.toJson());
    expect(restored.weeklySequence, ['A','B','C','D','A']);
    expect(restored.copyWith(name: 'Other').weeklySequence, restored.weeklySequence);
    final template = restored.toTemplate(newId: 't', newName: 'T', now: monday);
    expect(template.instantiateTemplate(newId: 'p2', newName: 'P2', now: monday)
        .weeklySequence, restored.weeklySequence);
    expect(restored.duplicate(newId: 'p3', newName: 'P3', now: monday).weeklySequence,
        restored.weeklySequence);
    expect(restored.copyWith(routineIds: ['A','B']).weeklySequence,
        ['A','B','A','B','A']);
  });

  test('fixed calendar ignores weekly sequence and flexible has no stale weekdays', () {
    final fixed = plan(mode: ProgramScheduleMode.fixed).copyWith(
        fixedWeekdayRoutineIds: {1:'D',3:'C'});
    expect(projection(fixed), ['D','C','D','C']);
    expect(ProgramScheduleProjector.effectiveTrainingWeekdays(plan(), const []), isEmpty);
    expect(plan().copyWith(targetSessionsPerWeek: 0).effectiveTargetSessionsPerWeek, 4);
  });
}
