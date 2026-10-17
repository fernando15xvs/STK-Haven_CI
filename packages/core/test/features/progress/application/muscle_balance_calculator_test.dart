import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/progress/application/muscle_balance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const primary = Exercise(
    id: 'press',
    name: 'Press de banca',
    muscleGroup: 'Pecho',
    secondaryMuscles: ['Tríceps', 'TRÍCEPS', 'Pecho'],
  );
  const inactive = Exercise(
    id: 'legs',
    name: 'Sentadillas',
    muscleGroup: 'Piernas',
  );
  const curl = Exercise(
    id: 'curl',
    name: 'Curl',
    muscleGroup: 'Bíceps',
    secondaryMuscles: ['Antebrazo'],
  );
  final routine = Routine(
    id: 'r1',
    name: 'Upper',
    scheduledDays: const [1],
    createdAt: DateTime(2026, 1, 1),
    exercises: const [
      RoutineExercise(
        exerciseId: 'press', order: 0, targetSets: 3,
        targetRepsMin: 8, targetRepsMax: 10, restSeconds: 120,
        warmupSets: 1, approachSets: 1,
      ),
      RoutineExercise(
        exerciseId: 'curl', order: 1, targetSets: 2,
        targetRepsMin: 8, targetRepsMax: 12, restSeconds: 90,
      ),
    ],
  );

  WorkoutSession session({
    required String id,
    required DateTime date,
    List<WorkoutSet> pressSets = const [],
    List<WorkoutSet> curlSets = const [],
    bool includeCurl = false,
    String? routineId = 'r1',
  }) => WorkoutSession(
    id: id,
    routineId: routineId,
    routineNameSnapshot: 'Upper',
    startedAt: date.subtract(const Duration(minutes: 40)),
    finishedAt: date,
    durationSeconds: 2400,
    exercises: [
      WorkoutExercise(
        exerciseId: 'press',
        exerciseNameSnapshot: 'Press de banca',
        muscleGroupSnapshot: 'Pecho',
        sets: pressSets,
      ),
      if (includeCurl)
        WorkoutExercise(
          exerciseId: 'curl',
          exerciseNameSnapshot: 'Curl unilateral',
          muscleGroupSnapshot: 'Bíceps',
          unilateral: true,
          sets: curlSets,
        ),
    ],
  );

  const work = WorkoutSet(weight: 60, reps: 8, completed: true);
  const incomplete = WorkoutSet(weight: 75, reps: 5, completed: false);
  const warmup = WorkoutSet(
    weight: 30, reps: 12, completed: true, setType: WorkoutSetType.warmup,
  );
  const approach = WorkoutSet(
    weight: 45, reps: 6, completed: true, setType: WorkoutSetType.approach,
  );

  final now = DateTime(2026, 10, 17, 12);
  final history = [
    session(
      id: 'previous-full-week',
      date: DateTime(2026, 9, 30, 12),
      pressSets: [work],
    ),
    session(
      id: 'recent-full-week',
      date: DateTime(2026, 10, 7, 12),
      pressSets: [warmup, approach, work, work, incomplete],
      includeCurl: true,
      curlSets: const [
        WorkoutSet(
          weight: 10, reps: 10, completed: true,
          leftCompleted: true, rightCompleted: true,
          leftWeight: 10, leftReps: 10,
          rightWeight: 10, rightReps: 10,
        ),
        WorkoutSet(
          weight: 11, reps: 9, completed: false,
          leftCompleted: true, rightCompleted: false,
        ),
      ],
    ),
    session(
      id: 'current-incomplete-week',
      date: DateTime(2026, 10, 14, 12),
      pressSets: [work, work],
    ),
  ];
  MuscleBalanceReport calculate({
    Iterable<WorkoutSession>? sessions,
    DateTime? from,
    Iterable<Exercise> exerciseList = const [primary, inactive, curl],
    Iterable<Routine>? routines,
  }) => MuscleBalanceCalculator.calculate(
    history: sessions ?? history,
    exercises: exerciseList,
    routines: routines ?? [routine],
    from: from ?? DateTime(2026, 9, 1),
    now: now,
  );

  MuscleBalanceItem muscle(MuscleBalanceReport report, String group) =>
      report.groups.singleWhere((g) => g.name == group);

  test('counts completed working sets and unique days, never warmups/sides', () {
    final report = calculate();
    final chest = muscle(report, 'Pecho');
    expect(chest.directSets, 5);
    expect(chest.trainingDays, 3);
    expect(chest.directExerciseSets['Press de banca'], 5);
    expect(chest.lastTrainedAt, DateTime(2026, 10, 14, 12));
    expect(muscle(report, 'Bíceps').directSets, 1);
    expect(muscle(report, 'Piernas').directSets, 0);
    expect(muscle(report, 'Piernas').lastTrainedAt, isNull);
    expect(report.totalDirectSets, 6);
  });

  test('secondary exposure is clearly separate and case-insensitive', () {
    final report = calculate();
    expect(muscle(report, 'Tríceps').directSets, 0);
    expect(muscle(report, 'Tríceps').estimatedSecondarySets, 2.5);
    expect(muscle(report, 'Pecho').estimatedSecondarySets, 0);
    expect(muscle(report, 'Antebrazo').estimatedSecondarySets, 0.5);
  });

  test('compares only two complete Monday-Sunday weeks', () {
    final chest = muscle(calculate(), 'Pecho');
    expect(chest.previousFullWeekSets, 1);
    expect(chest.recentFullWeekSets, 2);
    expect(chest.previousFullWeekDays, 1);
    expect(chest.recentFullWeekDays, 1);
    final report = calculate();
    expect(report.previousWeekStart, DateTime(2026, 9, 28));
    expect(report.recentWeekStart, DateTime(2026, 10, 5));
  });

  test('planning uses only observed sessions and current routine template', () {
    final report = calculate();
    expect(report.sessionsWithComparablePlan, 3);
    expect(muscle(report, 'Pecho').plannedSetsInPerformedSessions, 9);
    expect(muscle(report, 'Pecho').completedSetsInPlannedExercises, 5);
    expect(muscle(report, 'Bíceps').plannedSetsInPerformedSessions, 6);
    expect(muscle(report, 'Bíceps').completedSetsInPlannedExercises, 1);
    expect(muscle(report, 'Piernas').plannedSetsInPerformedSessions, isNull);
    expect(calculate(routines: []).sessionsWithComparablePlan, 0);
    expect(muscle(calculate(routines: []), 'Pecho')
        .plannedSetsInPerformedSessions, isNull);
  });

  test('empty period keeps catalog groups; future sessions are ignored', () {
    final future = session(
      id: 'future',
      date: DateTime(2026, 10, 20),
      pressSets: [work],
    );
    final report = calculate(
      sessions: [future],
      from: DateTime(2026, 10, 10),
    );
    expect(report.hasRecordedWork, false);
    expect(report.groups.any((m) => m.name == 'Piernas'), true);
    expect(muscle(report, 'Pecho').directSets, 0);
  });

  test('different sessions on the same day count once for frequency', () {
    final sameDay = calculate(
      sessions: [
        session(
          id: 'one', date: DateTime(2026, 10, 7, 10), pressSets: [work],
        ),
        session(
          id: 'two', date: DateTime(2026, 10, 7, 18), pressSets: [work],
        ),
      ],
    );
    expect(muscle(sameDay, 'Pecho').directSets, 2);
    expect(muscle(sameDay, 'Pecho').trainingDays, 1);
    expect(muscle(sameDay, 'Pecho').recentFullWeekDays, 1);
  });

  test('historical primary snapshot survives catalog changes', () {
    final report = calculate(
      exerciseList: const [inactive, curl],
    );
    expect(muscle(report, 'Pecho').directSets, 5);
    expect(report.groups.where((g) => g.name == 'Tríceps'), isEmpty);
  });
}
