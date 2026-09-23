import 'package:flutter_test/flutter_test.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/personal_record.dart';
import 'package:core/domain/models/progression_suggestion.dart';

void main() {
  group('FitnessFormatter', () {
    test('formatWeight formats properly based on unit', () {
      expect(FitnessFormatter.formatWeight(100.0, WeightUnit.kg), '100 kg');
      // 100 kg -> 220.462 lb -> '220.5 lb'
      expect(FitnessFormatter.formatWeight(100.0, WeightUnit.lb), '220.5 lb');
    });

    test('formatProgressionTarget handles integers', () {
      final res = FitnessFormatter.formatProgressionTarget(100.0, 8, 12, WeightUnit.kg);
      expect(res, '100 kg × 8-12');
    });


    test('explains the evidence behind a cautious progression result', () {
      const suggestion = ProgressionSuggestion(
        exerciseId: 'ex1',
        exerciseName: 'Press',
        currentWeightKg: 40,
        suggestedWeightKg: 40,
        suggestedRepsMin: 8,
        suggestedRepsMax: 12,
        type: ProgressionType.maintain,
        reason: ProgressionReason.recoveryCaution,
        evidenceSessions: 2,
      );

      expect(
        FitnessFormatter.progressionTitle(suggestion),
        'Mantén la referencia',
      );
      expect(
        FitnessFormatter.progressionExplanation(suggestion),
        contains('check-in'),
      );
      expect(
        FitnessFormatter.progressionEvidence(suggestion),
        'Basado en 2 sesiones comparables',
      );
      expect(
        FitnessFormatter.progressionSafetyNote,
        contains('sin molestias'),
      );
    });

    test('formatPRValue formats based on PR type', () {
      final w = FitnessFormatter.formatPRValue(100.0, PRType.maxWeight, WeightUnit.kg);
      expect(w, '100 kg');
      
      final vol = FitnessFormatter.formatPRValue(1000.0, PRType.bestSetVolume, WeightUnit.kg);
      expect(vol, '1000 kg·reps');
    });
  });
}
