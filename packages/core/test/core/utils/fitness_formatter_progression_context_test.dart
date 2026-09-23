import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/domain/models/progression_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('different rep context is explicit in progression copy', () {
    final suggestion = ProgressionSuggestion(
      exerciseId: 'press',
      exerciseName: 'Press Inclinado',
      currentWeightKg: 50,
      suggestedWeightKg: 50,
      suggestedRepsMin: 6,
      suggestedRepsMax: 8,
      type: ProgressionType.maintain,
      reason: ProgressionReason.differentRepContext,
      evidenceSessions: 1,
      sourceRoutineName: 'Push A',
      sourcePerformedAt: DateTime(2026, 9, 7),
      sourceRepsMin: 12,
      sourceRepsMax: 15,
      differentContext: true,
      sourceEstimated1RmKg: 78.3,
    );

    expect(
      FitnessFormatter.progressionTitle(suggestion),
      'Contexto distinto entre rutinas',
    );
    expect(
      FitnessFormatter.progressionExplanation(suggestion),
      contains('e1RM/RIR'),
    );
    expect(
      FitnessFormatter.progressionEvidence(suggestion),
      'Última vez: 07/09 · Push A · Contexto distinto · 12-15 reps · e1RM/RIR considerado',
    );
  });
}
