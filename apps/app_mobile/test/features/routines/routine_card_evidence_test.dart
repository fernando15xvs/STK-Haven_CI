import 'package:core/domain/models/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/routines/application/routine_card_evidence.dart';

WorkoutSession sample(
  String id, {
  String? routineId = 'routine-a',
  int minutes = 40,
  bool complete = true,
  DateTime? finishedAt,
}) {
  final finished = finishedAt ?? DateTime(2026, 11, 10, 18);
  return WorkoutSession(
    id: id,
    routineId: routineId,
    routineNameSnapshot: 'Rutina histórica',
    startedAt: finished.subtract(Duration(minutes: minutes)),
    finishedAt: finished,
    durationSeconds: minutes * 60,
    exercises: [
      WorkoutExercise(
        exerciseId: 'exercise-1',
        exerciseNameSnapshot: 'Ejercicio',
        muscleGroupSnapshot: 'Pecho',
        sets: [
          WorkoutSet(weight: 20, reps: 8, completed: complete),
        ],
      ),
    ],
  );
}

void main() {
  final asOf = DateTime(2026, 11, 13, 20);

  test('only completed sessions with matching routine ID count', () {
    final result = RoutineCardEvidence.fromHistory([
      sample('first', finishedAt: DateTime(2026, 11, 9)),
      sample('partial', complete: false,
          finishedAt: DateTime(2026, 11, 12)),
      sample('missing-id', routineId: null,
          finishedAt: DateTime(2026, 11, 12)),
      sample('future', finishedAt: DateTime(2026, 11, 15)),
      sample('zero-duration', minutes: 0,
          finishedAt: DateTime(2026, 11, 12)),
    ], asOf: asOf);
    expect(result.keys, ['routine-a']);
    expect(result['routine-a']!.lastFinishedAt,
        DateTime(2026, 11, 9));
    expect(result['routine-a']!.typicalMinutes, isNull);
  });

  test('typical duration uses median of three valid completed sessions', () {
    final result = RoutineCardEvidence.fromHistory([
      sample('a', minutes: 30, finishedAt: DateTime(2026, 11, 6)),
      sample('b', minutes: 45, finishedAt: DateTime(2026, 11, 8)),
      sample('c', minutes: 100, finishedAt: DateTime(2026, 11, 10)),
      sample('other', routineId: 'routine-b', minutes: 90),
    ], asOf: asOf);
    expect(result['routine-a']!.typicalMinutes, 45);
    expect(result['routine-b']!.typicalMinutes, isNull);
    expect(result['routine-a']!.lastFinishedAt, DateTime(2026, 11, 10));
  });
}
