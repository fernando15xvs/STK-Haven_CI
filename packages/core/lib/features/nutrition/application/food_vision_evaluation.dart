import 'package:core/domain/models/nutrition_intelligence.dart';

class FoodVisionEvaluationResult {
  final bool passed;
  final List<String> failures;

  const FoodVisionEvaluationResult({
    required this.passed,
    required this.failures,
  });
}

class FoodVisionEvaluationContract {
  const FoodVisionEvaluationContract._();

  static FoodVisionEvaluationResult validate({
    required FoodVisionEstimate estimate,
    required int minimumItems,
    required bool requiresQuestion,
    required FoodVisionConfidence maximumConfidence,
  }) {
    final failures = <String>[];

    if (estimate.items.length < minimumItems) {
      failures.add(
        'Esperaba al menos $minimumItems componentes y recibió '
        '${estimate.items.length}.',
      );
    }

    if (requiresQuestion && estimate.questions.isEmpty) {
      failures.add(
        'El caso requiere al menos una pregunta para resolver incertidumbre.',
      );
    }

    if (_rank(estimate.confidence) > _rank(maximumConfidence)) {
      failures.add(
        'La confianza ${estimate.confidence.name} supera el máximo '
        '${maximumConfidence.name} permitido por el caso.',
      );
    }

    return FoodVisionEvaluationResult(
      passed: failures.isEmpty,
      failures: List<String>.unmodifiable(failures),
    );
  }

  static int _rank(FoodVisionConfidence value) => switch (value) {
        FoodVisionConfidence.low => 0,
        FoodVisionConfidence.medium => 1,
        FoodVisionConfidence.high => 2,
      };
}
