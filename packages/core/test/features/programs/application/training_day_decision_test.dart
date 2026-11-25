import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/training_program.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/programs/application/training_day_decision.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 11, 25, 12);
  final next = Routine(id: 'b', name: 'Lower B', scheduledDays: const [],
      exercises: const [], createdAt: now);
  final done = WorkoutSession(id: 'finished', routineId: 'a', routineNameSnapshot: 'Upper A',
      startedAt: now.subtract(const Duration(hours: 2)),
      finishedAt: now.subtract(const Duration(hours: 1)), durationSeconds: 3600,
      exercises: [
        WorkoutExercise(exerciseId: 'press', exerciseNameSnapshot: 'Press',
          muscleGroupSnapshot: 'Pecho', sets: const [
          WorkoutSet(weight: 50, reps: 8, completed: true),
        ]),
      ]);
  TrainingDayDecision resolve({DateTime? at, WorkoutSession? active,
      List<WorkoutSession> history = const [],
      ProgramScheduleMode mode = ProgramScheduleMode.flexible, DateTime? date}) =>
      TrainingDayDecision.resolve(now: at ?? now, active: active, history: history,
          next: next, mode: mode, scheduledDate: date, isTrainingDay: true);

  test('flexible starts today, preserves completed hero, and advances tomorrow', () {
    expect(resolve().kind, TrainingDayKind.ready);
    final completed = resolve(history: [done]);
    expect(completed.kind, TrainingDayKind.completed);
    expect(completed.featuredRoutineId, 'a');
    expect(completed.allowsSuggestedStart, isFalse);
    final tomorrow = resolve(at: DateTime(2026, 11, 26), history: [done]);
    expect(tomorrow.kind, TrainingDayKind.ready);
    expect(tomorrow.featuredRoutineId, 'b');
  });
  test('active session wins over completion and calendar', () {
    expect(resolve(active: done, history: [done]).kind, TrainingDayKind.active);
  });
  test('future projected date means rest even with incorrect today flag', () {
    final rest = resolve(mode: ProgramScheduleMode.fixed, date: DateTime(2026, 11, 27));
    expect(rest.kind, TrainingDayKind.rest);
    expect(rest.allowsSuggestedStart, isFalse);
    expect(rest.featuredRoutineId, isNull);
    expect(rest.routine?.id, 'b');
    expect(resolve(date: DateTime(2026, 11, 27)).kind, TrainingDayKind.rest);
    expect(resolve(mode: ProgramScheduleMode.continuous, date: now).kind,
        TrainingDayKind.ready);
  });
  test('paused, goal reached and unavailable plans never feature a routine', () {
    for (final reason in [TrainingRestReason.paused, TrainingRestReason.goalReached, TrainingRestReason.unavailable]) {
      final result = TrainingDayDecision.resolve(now: now, active: null, history: [],
        next: null, mode: ProgramScheduleMode.flexible, scheduledDate: null,
        isTrainingDay: true, hasProgram: true, legacyToday: next,
        programPaused: reason == TrainingRestReason.paused,
        goalReached: reason == TrainingRestReason.goalReached);
      expect(result.kind, TrainingDayKind.rest);
      expect(result.restReason, reason);
      expect(result.featuredRoutineId, isNull);
      expect(result.allowsSuggestedStart, isFalse);
    }
    final result = TrainingDayDecision.resolve(now: now, active: done, history: [done],
      next: next, mode: ProgramScheduleMode.flexible, scheduledDate: null,
      isTrainingDay: true, programPaused: true, goalReached: true);
    expect(result.kind, TrainingDayKind.active);
  });
  test('rotation uses saved pointer, without assigning weekdays', () {
    final program = TrainingProgram(id: 'p', name: 'STK', routineIds: const ['a','b','c'],
      createdAt: now, startedAt: now, scheduleMode: ProgramScheduleMode.flexible,
      nextRotationIndex: 1, trainingWeekdays: const {1, 3});
    expect(TrainingDayDecision.rotationOrder(program), ['b','c','a']);
  });
}
