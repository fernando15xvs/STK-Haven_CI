import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/workout_summary_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WorkoutSession session(List<WorkoutExercise> exercises) {
    return WorkoutSession(
      id: 'session-1',
      routineId: 'routine-1',
      routineNameSnapshot: 'Full body',
      startedAt: DateTime(2026, 9, 2, 17),
      finishedAt: DateTime(2026, 9, 2, 18),
      durationSeconds: 3600,
      exercises: exercises,
    );
  }

  group('WorkoutSummarySnapshot', () {
    test('summarizes working-set completion per exercise', () {
      final snapshot = WorkoutSummarySnapshot.fromSession(
        session([
          WorkoutExercise(
            exerciseId: 'press',
            exerciseNameSnapshot: 'Press',
            muscleGroupSnapshot: 'Pecho',
            sets: const [
              WorkoutSet(
                weight: 20,
                reps: 10,
                completed: true,
                setType: WorkoutSetType.warmup,
              ),
              WorkoutSet(
                weight: 30,
                reps: 8,
                completed: true,
                setType: WorkoutSetType.approach,
              ),
              WorkoutSet(
                weight: 40,
                reps: 10,
                completed: true,
                rir: 2,
              ),
              WorkoutSet(
                weight: 40,
                reps: 10,
                completed: false,
                rir: 1,
              ),
            ],
          ),
          WorkoutExercise(
            exerciseId: 'row',
            exerciseNameSnapshot: 'Remo',
            muscleGroupSnapshot: 'Espalda',
            sets: const [
              WorkoutSet(
                weight: 35,
                reps: 12,
                completed: true,
                rir: 4,
              ),
            ],
          ),
        ]),
      );

      expect(snapshot.plannedWorkingSets, 3);
      expect(snapshot.completedWorkingSets, 2);
      expect(snapshot.completionPercent, 67);
      expect(snapshot.totalExercises, 2);
      expect(snapshot.completedExercises, 1);
      expect(snapshot.exercises.first.completionPercent, 50);
      expect(snapshot.exercises.last.isComplete, true);
    });

    test('averages only logged RIR from completed working sets', () {
      final snapshot = WorkoutSummarySnapshot.fromSession(
        session([
          WorkoutExercise(
            exerciseId: 'press',
            exerciseNameSnapshot: 'Press',
            muscleGroupSnapshot: 'Pecho',
            sets: const [
              WorkoutSet(weight: 40, reps: 10, completed: true, rir: 2),
              WorkoutSet(weight: 40, reps: 10, completed: true),
              WorkoutSet(weight: 40, reps: 10, completed: true, rir: 4),
              WorkoutSet(
                weight: 20,
                reps: 10,
                completed: true,
                rir: 5,
                setType: WorkoutSetType.warmup,
              ),
            ],
          ),
        ]),
      );

      expect(snapshot.rirLoggedSets, 2);
      expect(snapshot.averageRir, 3);
    });

    test('returns a safe empty snapshot without working sets', () {
      final snapshot = WorkoutSummarySnapshot.fromSession(
        session(const []),
      );

      expect(snapshot.exercises, isEmpty);
      expect(snapshot.completionPercent, 0);
      expect(snapshot.averageRir, isNull);
      expect(snapshot.isComplete, false);
    });
  });
}
