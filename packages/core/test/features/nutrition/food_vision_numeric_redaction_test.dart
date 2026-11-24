import 'dart:io';

import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:test/test.dart';

void main(){
  FoodVisionEstimate makeEstimate({required bool numericAvailable})=>
      FoodVisionEstimate(
        dishName:'Arroz con pollo',
        items:[
          const FoodVisionItem(
            name:'Arroz',
            portionDescription:'Una porción',
            confidence:FoodVisionConfidence.medium,
            uncertaintyNote:'La porción no se puede medir con precisión.',
            gramsLow:100,
            gramsHigh:200,
            caloriesLow:120,
            caloriesHigh:300,
            proteinGramsLow:2,
            proteinGramsHigh:5,
            carbsGramsLow:20,
            carbsGramsHigh:60,
            fatGramsLow:1,
            fatGramsHigh:10,
          ),
        ],
        caloriesLow:300,caloriesHigh:600,
        proteinGramsLow:10,proteinGramsHigh:40,
        carbsGramsLow:50,carbsGramsHigh:100,
        fatGramsLow:5,fatGramsHigh:30,
        confidence:FoodVisionConfidence.low,
        numericNutritionAvailable:numericAvailable,
        assumptions:const ['No se puede ver la salsa.'],
        questions:const ['¿Llevaba aceite?'],
        disclaimer:'Estimación orientativa.',
      );

  test('descriptive-only parsing strips accidental numbers in every item',(){
    final legacy=makeEstimate(numericAvailable:true).toJson();
    legacy['numericNutritionAvailable']=false;
    final result=FoodVisionEstimate.fromJson(legacy);
    expect(result.numericNutritionAvailable,isFalse);
    expect(result.dishName,'Arroz con pollo');
    expect(result.confidence,FoodVisionConfidence.low);
    expect(result.questions,contains('¿Llevaba aceite?'));
    expect(result.caloriesLow,isNull);
    expect(result.caloriesHigh,isNull);
    expect(result.proteinGramsLow,isNull);
    expect(result.proteinGramsHigh,isNull);
    expect(result.carbsGramsLow,isNull);
    expect(result.carbsGramsHigh,isNull);
    expect(result.fatGramsLow,isNull);
    expect(result.fatGramsHigh,isNull);
    expect(result.items,hasLength(1));
    final arroz=result.items.single;
    expect(arroz.name,'Arroz');
    expect(arroz.portionDescription,'Una porción');
    expect(arroz.uncertaintyNote,contains('no se puede medir'));
    expect(arroz.gramsLow,isNull);
    expect(arroz.gramsHigh,isNull);
    expect(arroz.caloriesLow,isNull);
    expect(arroz.caloriesHigh,isNull);
    expect(arroz.proteinGramsLow,isNull);
    expect(arroz.proteinGramsHigh,isNull);
    expect(arroz.carbsGramsLow,isNull);
    expect(arroz.carbsGramsHigh,isNull);
    expect(arroz.fatGramsLow,isNull);
    expect(arroz.fatGramsHigh,isNull);
    expect(FoodVisionEstimate.fromJson(result.toJson()).items.single.caloriesLow,
      isNull);
  });

  test('even directly constructed descriptive estimates cannot persist numbers',(){
    final inconsistent=makeEstimate(numericAvailable:false);
    final saved=inconsistent.toJson();
    expect(saved['numericNutritionAvailable'],isFalse);
    expect(saved['caloriesLow'],isNull);
    expect(saved['fatGramsHigh'],isNull);
    final items=saved['items'] as List;
    expect(items,hasLength(1));
    final first=items.single as Map;
    for(final field in [
      'gramsLow','gramsHigh','caloriesLow','caloriesHigh',
      'proteinGramsLow','proteinGramsHigh',
      'carbsGramsLow','carbsGramsHigh',
      'fatGramsLow','fatGramsHigh'
    ]){
      expect(first[field],isNull,reason:'$field was leaked to JSON');
    }
    expect(first['name'],'Arroz');
  });

  test('an explicit no-grant response can be redacted despite a true flag',(){
    final response=makeEstimate(numericAvailable:true);
    final redacted=response.withoutNumericNutrition();
    expect(redacted.numericNutritionAvailable,isFalse);
    expect(redacted.caloriesLow,isNull);
    expect(redacted.items.single.caloriesLow,isNull);
    expect(response.numericNutritionAvailable,isTrue);
    expect(response.caloriesLow,300);
    expect(response.items.single.caloriesLow,120);
    expect(redacted.assumptions,response.assumptions);
    expect(redacted.disclaimer,response.disclaimer);
  });

  test('typed adult fields survive only when the numerical flag is true',(){
    final parsed=FoodVisionEstimate.fromJson(
      makeEstimate(numericAvailable:true).toJson());
    expect(parsed.numericNutritionAvailable,isTrue);
    expect(parsed.caloriesLow,300);
    expect(parsed.items.single.gramsLow,100);
    expect(parsed.items.single.proteinGramsLow,2);
  });

  test('server strips estimated grams and macros for descriptive-only accounts',(){
    final edge=File(
      '../../supabase/functions/food-vision-ai/index.ts',
    ).readAsStringSync();
    final start=edge.indexOf('if (!adultNumericNutrition) {');
    expect(start,greaterThanOrEqualTo(0));
    final body=edge.substring(start);
    expect(body,contains('estimate.numericNutritionAvailable = false;'));
    expect(body,contains('gramsLow: null,'));
    expect(body,contains('gramsHigh: null,'));
    expect(body,contains('caloriesLow: null,'));
    expect(body,contains('caloriesHigh: null,'));
    expect(body,contains('proteinGramsLow: null,'));
    expect(body,contains('carbsGramsHigh: null,'));
    expect(body,contains('fatGramsHigh: null,'));
    expect(edge,contains("payload.adultNumericNutrition === true &&"));
    expect(edge,contains('hasVerifiedAdultNutritionAccess'));
  });

  test('service fails closed when request is descriptive, even if server grants',(){
    final source=File(
      'lib/features/nutrition/data/food_vision_service.dart',
    ).readAsStringSync();
    expect(source,contains('return adultNumericNutrition'));
    expect(source,contains('?estimate:estimate.withoutNumericNutrition()'));
    expect(source,contains("'adultNumericNutrition': adultNumericNutrition"));
  });
}
