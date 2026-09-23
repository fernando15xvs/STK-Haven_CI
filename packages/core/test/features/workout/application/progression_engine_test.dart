import 'package:core/domain/models/progression_suggestion.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/progression_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const target = RoutineExercise(
    exerciseId: 'ex_1',
    order: 0,
    targetSets: 3,
    targetRepsMin: 8,
    targetRepsMax: 12,
    restSeconds: 90,
  );

  WorkoutSession session({
    required String id,
    required int day,
    double weight = 80,
    List<int> reps = const [12, 12, 12],
    List<int?> rir = const [3, 3, 3],
    int completedSets = 3,
  }) {
    return WorkoutSession(
      id: id,
      routineId: 'routine_1',
      routineNameSnapshot: 'Push A',
      startedAt: DateTime(2026, 9, day, 17),
      finishedAt: DateTime(2026, 9, day, 18),
      durationSeconds: 3600,
      exercises: [
        WorkoutExercise(
          exerciseId: 'ex_1',
          exerciseNameSnapshot: 'Bench Press',
          muscleGroupSnapshot: 'Pecho',
          sets: List.generate(
            reps.length,
            (index) => WorkoutSet(
              weight: weight,
              reps: reps[index],
              rir: rir[index],
              completed: index < completedSets,
            ),
          ),
        ),
      ],
    );
  }

  List<ProgressionSuggestion> analyze(
    WorkoutSession current, {
    Iterable<WorkoutSession> history = const [],
    bool rirEnabled = true,
    double increment = 2.5,
    ProgressionReadiness readiness = ProgressionReadiness.unknown,
  }) {
    return ProgressionEngine.analyze(
      session: current,
      routineTargets: const [target],
      isRirEnabled: rirEnabled,
      defaultIncrementKg: increment,
      recentSessions: history,
      readiness: readiness,
    );
  }

  group('ProgressionEngine refined evidence', () {
    test('asks to confirm a single top-range session before increasing', () {
      final suggestion = analyze(
        session(id: 'current', day: 2),
      ).single;

      expect(suggestion.type, ProgressionType.maintain);
      expect(suggestion.reason, ProgressionReason.confirmTopRange);
      expect(suggestion.evidenceSessions, 1);
      expect(suggestion.suggestedWeightKg, 80);
    });

    test('increases after two comparable top-range sessions', () {
      final previous = session(id: 'previous', day: 1);
      final current = session(id: 'current', day: 2);

      final suggestion = analyze(
        current,
        history: [previous],
      ).single;

      expect(suggestion.type, ProgressionType.increase);
      expect(suggestion.reason, ProgressionReason.consistentTopRange);
      expect(suggestion.evidenceSessions, 2);
      expect(suggestion.suggestedWeightKg, 82.5);
    });

    test('caps a configured increment at five percent of current load', () {
      final previous = session(
        id: 'previous',
        day: 1,
        weight: 20,
      );
      final current = session(
        id: 'current',
        day: 2,
        weight: 20,
      );

      final suggestion = analyze(
        current,
        history: [previous],
        increment: 2.5,
      ).single;

      expect(suggestion.type, ProgressionType.increase);
      expect(suggestion.suggestedWeightKg, 21);
    });

    test('preserves a five-pound increment when it is within the cap', () {
      const currentWeightKg = 45.3592;
      const fiveLbInKg = 2.26796;
      final previous = session(
        id: 'previous',
        day: 1,
        weight: currentWeightKg,
      );
      final current = session(
        id: 'current',
        day: 2,
        weight: currentWeightKg,
      );

      final suggestion = analyze(
        current,
        history: [previous],
        increment: fiveLbInKg,
      ).single;

      expect(suggestion.suggestedWeightKg, closeTo(47.627, 0.01));
      expect((suggestion.suggestedWeightKg - 47.5).abs() > 0.05, isTrue);
    });

    test('does not increase when recovery context is cautious', () {
      final suggestion = analyze(
        session(id: 'current', day: 2),
        history: [session(id: 'previous', day: 1)],
        readiness: ProgressionReadiness.caution,
      ).single;

      expect(suggestion.type, ProgressionType.maintain);
      expect(suggestion.reason, ProgressionReason.recoveryCaution);
      expect(suggestion.suggestedWeightKg, 80);
    });

    test('requires complete RIR data when RIR is enabled', () {
      final suggestion = analyze(
        session(
          id: 'current',
          day: 2,
          rir: const [3, null, 3],
        ),
        history: [session(id: 'previous', day: 1)],
      ).single;

      expect(suggestion.type, ProgressionType.maintain);
      expect(suggestion.reason, ProgressionReason.missingRir);
    });

    test('requires at least two RIR in every planned work set', () {
      final suggestion = analyze(
        session(
          id: 'current',
          day: 2,
          rir: const [2, 1, 2],
        ),
        history: [session(id: 'previous', day: 1)],
      ).single;

      expect(suggestion.type, ProgressionType.maintain);
      expect(suggestion.reason, ProgressionReason.effortTooHigh);
    });

    test('maintains load while repetitions remain below the top range', () {
      final suggestion = analyze(
        session(
          id: 'current',
          day: 2,
          reps: const [12, 11, 10],
        ),
        rirEnabled: false,
      ).single;

      expect(suggestion.type, ProgressionType.maintain);
      expect(suggestion.reason, ProgressionReason.buildRepetitions);
      expect(suggestion.suggestedWeightKg, 80);
    });

    test('returns insufficient data when planned work sets are incomplete', () {
      final suggestion = analyze(
        session(
          id: 'current',
          day: 2,
          completedSets: 2,
        ),
      ).single;

      expect(suggestion.type, ProgressionType.insufficientData);
      expect(suggestion.reason, ProgressionReason.incompleteWorkSets);
    });

    test('does not count a different previous load as confirmation', () {
      final suggestion = analyze(
        session(id: 'current', day: 2, weight: 80),
        history: [
          session(id: 'previous', day: 1, weight: 77.5),
        ],
      ).single;

      expect(suggestion.type, ProgressionType.maintain);
      expect(suggestion.reason, ProgressionReason.confirmTopRange);
    });
  });
}
