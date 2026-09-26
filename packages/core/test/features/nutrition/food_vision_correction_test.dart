import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/application/food_vision_correction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FoodVisionEstimate estimate() => FoodVisionEstimate.fromJson({
        'dishName': 'Plato mixto',
        'items': [
          {
            'name': 'Arroz',
            'portionDescription': 'porción visible',
            'confidence': 'medium',
          },
          {
            'name': 'Pollo',
            'portionDescription': '1 pieza',
            'confidence': 'medium',
          },
        ],
        'confidence': 'medium',
        'numericNutritionAvailable': false,
        'assumptions': const [],
        'questions': const [],
        'disclaimer': 'Estimación visual.',
      });

  test('draft starts from model without introducing numeric nutrition', () {
    final draft = FoodVisionCorrectionDraft.fromEstimate(
      estimate(),
      extraContext: 'sin salsa',
    );

    expect(draft.dishName, 'Plato mixto');
    expect(draft.items, hasLength(2));
    expect(draft.items.first.name, 'Arroz');
    expect(draft.items.first.portionDescription, 'porción visible');
  });

  test('structured correction context includes only user-edited fields', () {
    const draft = FoodVisionCorrectionDraft(
      dishName: 'Arroz con pollo',
      items: [
        FoodVisionCorrectionItem(
          name: 'Arroz',
          portionDescription: '1 taza',
        ),
        FoodVisionCorrectionItem(
          name: 'Pollo',
          portionDescription: '1 pieza mediana',
        ),
      ],
      extraContext: 'la salsa estaba aparte',
    );

    final context = draft.toReanalysisContext();

    expect(context, contains('Nombre corregido del plato: Arroz con pollo.'));
    expect(context, contains('1. Arroz — 1 taza.'));
    expect(context, contains('2. Pollo — 1 pieza mediana.'));
    expect(context, contains('la salsa estaba aparte'));
    expect(context.toLowerCase(), isNot(contains('kcal')));
    expect(context.toLowerCase(), isNot(contains('proteína')));
  });

  test('blank rows are omitted from reanalysis context', () {
    const draft = FoodVisionCorrectionDraft(
      dishName: '',
      items: [
        FoodVisionCorrectionItem(name: '', portionDescription: ''),
        FoodVisionCorrectionItem(name: 'Ensalada', portionDescription: ''),
      ],
    );

    final context = draft.toReanalysisContext();

    expect(context, contains('2. Ensalada.'));
    expect(context, isNot(contains('1. Ingrediente')));
  });
}
