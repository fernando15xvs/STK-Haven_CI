import 'package:core/domain/models/progression_suggestion.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/progression_engine.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session({
  required String id,
  required String routineId,
  required DateTime date,
  required double weight,
}) {
  return WorkoutSession(
    id: id,
    routineId: routineId,
    routineNameSnapshot: routineId,
    startedAt: date,
    finishedAt: date.add(const Duration(hours: 1)),
    durationSeconds: 3600,
    exercises: [
      WorkoutExercise(
        exerciseId: 'incline-press',
        exerciseNameSnapshot: 'Press inclinado',
        muscleGroupSnapshot: 'Pecho',
        sets: List.generate(
          3,
          (_) => WorkoutSet(
            weight: weight,
            reps: 10,
            rir: 2,
            completed: true,
          ),
        ),
      ),
    ],
  );
}

void main() {
  test('confirmation evidence can come from a different routine', () {
    final mondayPushA = _session(
      id: 'a',
      routineId: 'push-a',
      date: DateTime(2026, 9, 7),
      weight: 50,
    );
    final wednesdayPushB = _session(
      id: 'b',
      routineId: 'push-b',
      date: DateTime(2026, 9, 9),
      weight: 50,
    );

    const target = RoutineExercise(
      exerciseId: 'incline-press',
      order: 0,
      targetSets: 3,
      targetRepsMin: 8,
      targetRepsMax: 10,
      restSeconds: 120,
    );

    final result = ProgressionEngine.analyze(
      session: wednesdayPushB,
      routineTargets: const [target],
      isRirEnabled: true,
      defaultIncrementKg: 2.5,
      recentSessions: [mondayPushA],
    );

    expect(result, hasLength(1));
    expect(result.single.exerciseId, 'incline-press');
    expect(result.single.type, ProgressionType.increase);
    expect(result.single.evidenceSessions, 2);
  });
}
