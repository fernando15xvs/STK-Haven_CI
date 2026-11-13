import 'package:core/domain/models/active_program_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/home/application/home_dashboard_session_policy.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session(
  String id,
  DateTime startedAt, {
  String? routineId = 'program-routine',
  bool completed = true,
  bool withWorkingSet = true,
}) => WorkoutSession(
  id: id,
  routineId: routineId,
  routineNameSnapshot: 'Rutina',
  startedAt: startedAt,
  finishedAt: startedAt.add(const Duration(minutes: 45)),
  durationSeconds: 2700,
  exercises: [
    WorkoutExercise(
      exerciseId: 'press',
      exerciseNameSnapshot: 'Press',
      muscleGroupSnapshot: 'Pecho',
      sets: [
        WorkoutSet(
          weight: 20,
          reps: 8,
          completed: completed,
          setType: withWorkingSet
              ? WorkoutSetType.working
              : WorkoutSetType.warmup,
        ),
      ],
    ),
  ],
);

void main() {
  final start = DateTime(2026, 11, 1, 8);
  final program = ActiveProgramState(
    presetProgramId: 'preset',
    presetVersion: 1,
    programNameSnapshot: 'Programa',
    startedAt: start,
    durationWeeks: 8,
    generatedRoutineIds: const ['program-routine'],
  );

  test('program totals count complete effective sessions only', () {
    final rows = [
      _session('complete', start),
      _session('partial', start.add(const Duration(days: 1)), completed: false),
      _session('warmup', start.add(const Duration(days: 2)), withWorkingSet: false),
      _session('unrelated', start.add(const Duration(days: 3)), routineId: 'other'),
      _session('before', start.subtract(const Duration(minutes: 1))),
    ];
    expect(
      HomeDashboardSessionPolicy.completedProgramSessions(
        history: rows,
        activeProgram: program,
      ),
      1,
    );
  });

  test('future imports and repeated IDs never inflate completion total', () {
    final complete = _session('stable', start);
    final duplicate = _session('stable', start.add(const Duration(hours: 1)));
    final future = _session('future', start.add(const Duration(days: 5)));
    expect(
      HomeDashboardSessionPolicy.completedProgramSessions(
        history: [complete, duplicate, future],
        activeProgram: program,
        now: start.add(const Duration(days: 1)),
      ),
      1,
    );
  });

  test('a session started at program activation qualifies', () {
    expect(
      HomeDashboardSessionPolicy.completedProgramSessions(
        history: [_session('same-instant', start)],
        activeProgram: program,
      ),
      1,
    );
  });

  test('the completed-today banner owns the most recent session', () {
    final latest = _session('today', start.add(const Duration(days: 1)));
    final older = _session('older', start);
    expect(
      HomeDashboardSessionPolicy.recentWorkout(
        history: [latest, older],
        completedToday: latest,
      ),
      isNull,
    );
    expect(
      HomeDashboardSessionPolicy.recentWorkout(
        history: [latest, older],
        completedToday: null,
      ),
      same(latest),
    );
    expect(
      HomeDashboardSessionPolicy.recentWorkout(
        history: [],
        completedToday: null,
      ),
      isNull,
    );
  });
}
