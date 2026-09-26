import 'dart:convert';
import 'dart:io';

import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/application/food_vision_evaluation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Food Vision eval dataset covers all Roadmap 3 risk categories', () {
    final file = File('test/fixtures/food_vision_eval_cases.json');
    final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    final categories = decoded
        .map((e) => (e as Map<String, dynamic>)['category'])
        .toSet();

    expect(
      categories,
      containsAll(<String>{
        'simple',
        'mixed',
        'hidden_sauce',
        'low_confidence',
      }),
    );
  });

  test('hidden sauce case rejects unjustified high confidence', () {
    final estimate = FoodVisionEstimate.fromJson({
      'dishName': 'Pasta',
      'items': [
        {
          'name': 'Pasta',
          'portionDescription': 'porción visible',
          'confidence': 'high',
        },
      ],
      'confidence': 'high',
      'numericNutritionAvailable': false,
      'assumptions': ['No se conoce la salsa exacta.'],
      'questions': ['¿Qué salsa o aceite se usó?'],
      'disclaimer': 'Estimación visual.',
    });

    final result = FoodVisionEvaluationContract.validate(
      estimate: estimate,
      minimumItems: 1,
      requiresQuestion: true,
      maximumConfidence: FoodVisionConfidence.medium,
    );

    expect(result.passed, isFalse);
    expect(result.failures.join(' '), contains('confianza'));
  });

  test('low visibility requires question and low confidence', () {
    final estimate = FoodVisionEstimate.fromJson({
      'dishName': 'Plato parcialmente visible',
      'items': const [],
      'confidence': 'low',
      'numericNutritionAvailable': false,
      'assumptions': const [],
      'questions': ['¿Puedes indicar qué ingredientes no se ven?'],
      'disclaimer': 'Estimación visual con baja confianza.',
    });

    final result = FoodVisionEvaluationContract.validate(
      estimate: estimate,
      minimumItems: 0,
      requiresQuestion: true,
      maximumConfidence: FoodVisionConfidence.low,
    );

    expect(result.passed, isTrue);
  });

  test('simple and mixed cases satisfy minimum component expectations', () {
    final simple = FoodVisionEstimate.fromJson({
      'dishName': 'Fruta',
      'items': [
        {
          'name': 'Fruta',
          'portionDescription': '1 unidad visible',
          'confidence': 'high',
        },
      ],
      'confidence': 'high',
      'numericNutritionAvailable': false,
      'assumptions': const [],
      'questions': const [],
      'disclaimer': 'Estimación visual.',
    });
    final mixed = FoodVisionEstimate.fromJson({
      'dishName': 'Plato mixto',
      'items': [
        {'name': 'Arroz', 'confidence': 'medium'},
        {'name': 'Pollo', 'confidence': 'medium'},
        {'name': 'Ensalada', 'confidence': 'medium'},
      ],
      'confidence': 'medium',
      'numericNutritionAvailable': false,
      'assumptions': const [],
      'questions': const [],
      'disclaimer': 'Estimación visual.',
    });

    expect(
      FoodVisionEvaluationContract.validate(
        estimate: simple,
        minimumItems: 1,
        requiresQuestion: false,
        maximumConfidence: FoodVisionConfidence.high,
      ).passed,
      isTrue,
    );
    expect(
      FoodVisionEvaluationContract.validate(
        estimate: mixed,
        minimumItems: 2,
        requiresQuestion: false,
        maximumConfidence: FoodVisionConfidence.high,
      ).passed,
      isTrue,
    );
  });
}
