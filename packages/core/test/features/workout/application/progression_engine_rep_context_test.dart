import 'package:core/domain/models/progression_suggestion.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/progression_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const target = RoutineExercise(
    exerciseId: 'press',
    order: 0,
    targetSets: 3,
    targetRepsMin: 6,
    targetRepsMax: 8,
    restSeconds: 120,
  );

  WorkoutSession sourceSession({int? rir = 2}) => WorkoutSession(
        id: 'push-a-session',
        routineId: 'push-a',
        routineNameSnapshot: 'Push A',
        startedAt: DateTime(2026, 9, 7),
        finishedAt: DateTime(2026, 9, 7, 1),
        durationSeconds: 3600,
        exercises: [
          WorkoutExercise(
            exerciseId: 'press',
            exerciseNameSnapshot: 'Press Inclinado',
            muscleGroupSnapshot: 'Pecho',
            sets: [
              WorkoutSet(
                weight: 50,
                reps: 15,
                rir: rir,
                completed: true,
              ),
              WorkoutSet(
                weight: 50,
                reps: 14,
                rir: rir,
                completed: true,
              ),
              WorkoutSet(
                weight: 50,
                reps: 13,
                rir: rir,
                completed: true,
              ),
            ],
          ),
        ],
      );

  test('different rep context keeps load and exposes e1RM/RIR evidence', () {
    final suggestions = ProgressionEngine.analyze(
      session: sourceSession(),
      routineTargets: const [target],
      isRirEnabled: true,
      defaultIncrementKg: 2.5,
      sourceRoutineName: 'Push A',
      sourceRepsMin: 12,
      sourceRepsMax: 15,
      differentContext: true,
    );

    expect(suggestions, hasLength(1));
    final suggestion = suggestions.single;
    expect(suggestion.type, ProgressionType.maintain);
    expect(suggestion.reason, ProgressionReason.differentRepContext);
    expect(suggestion.suggestedWeightKg, 50);
    expect(suggestion.suggestedRepsMin, 6);
    expect(suggestion.suggestedRepsMax, 8);
    expect(suggestion.differentContext, isTrue);
    expect(suggestion.sourceRoutineName, 'Push A');
    expect(suggestion.sourceRepsMin, 12);
    expect(suggestion.sourceRepsMax, 15);
    expect(suggestion.sourceEstimated1RmKg, isNotNull);
    expect(suggestion.sourceEstimated1RmKg!, greaterThan(50));
  });

  test('different rep context still refuses automatic progression without RIR', () {
    final suggestions = ProgressionEngine.analyze(
      session: sourceSession(rir: null),
      routineTargets: const [target],
      isRirEnabled: true,
      defaultIncrementKg: 2.5,
      sourceRoutineName: 'Push A',
      sourceRepsMin: 12,
      sourceRepsMax: 15,
      differentContext: true,
    );

    expect(suggestions.single.type, ProgressionType.maintain);
    expect(suggestions.single.reason, ProgressionReason.missingRir);
    expect(suggestions.single.differentContext, isTrue);
  });
}
