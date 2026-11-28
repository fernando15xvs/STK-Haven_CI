import 'dart:io';
import '../../../support/nutrition_page_source.dart';
import 'package:core/domain/models/nutrition_history_entry.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/data/nutrition_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main(){
  NutritionHistoryEntry entry(String id,{bool favorite=false})=>
    NutritionHistoryEntry(
      id:id, analyzedAt:DateTime(2026,11,15),dishHint:'sin foto',
      estimate:const FoodVisionEstimate(
        dishName:'Comida de prueba',items:[],
        confidence:FoodVisionConfidence.medium,
        numericNutritionAvailable:false,
        disclaimer:'Descriptivo'),
      isFavorite:favorite,
    );

  test('old records migrate with favorite=false, no food photo required',(){
    final old=entry('legacy').toJson()..remove('isFavorite');
    final restored=NutritionHistoryEntry.fromJson(old);
    expect(restored.isFavorite,isFalse);
    expect(restored.copyWith(isFavorite:true).toJson()['isFavorite'],true);
  });

  test('legacy favorite flag survives JSON roundtrip',(){
    final source=entry('starred',favorite:true);
    expect(NutritionHistoryEntry.fromJson(source.toJson()).isFavorite,isTrue);
  });

  group('per-account favorite persistence',(){
    late Directory temp;
    late Box<dynamic> box;
    setUp(() async {
      temp=await Directory.systemTemp.createTemp('stk_food_favs_');
      Hive.init(temp.path);
      box=await Hive.openBox<dynamic>('food_favs');
    });
    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('food_favs');
      if(await temp.exists())await temp.delete(recursive:true);
    });

    test('favorites never leak between accounts and retain the estimate',()async{
      final own=NutritionHistoryRepository(box,ownerId:'uid-a');
      final other=NutritionHistoryRepository(box,ownerId:'uid-b');
      await own.save(entry('one'));
      await own.setFavorite('one',true);
      final saved=own.getEntries().single;
      expect(saved.isFavorite,isTrue);
      expect(saved.estimate.dishName,'Comida de prueba');
      expect(other.getEntries(),isEmpty);
      await own.setFavorite('one',false);
      expect(own.getEntries().single.isFavorite,isFalse);
    });

    test('frequent meals count only user-saved names in this account',()async{
      final own=NutritionHistoryRepository(box,ownerId:'uid-a');
      final other=NutritionHistoryRepository(box,ownerId:'uid-b');
      Future<void> save(String id,int day,String dish) async {
        await own.save(NutritionHistoryEntry(
          id:id,analyzedAt:DateTime(2026,11,day),dishHint:'',
          estimate:FoodVisionEstimate(
            dishName:dish,items:const [],
            confidence:FoodVisionConfidence.medium,
            numericNutritionAvailable:false,disclaimer:'Descriptivo'),
        ));
      }
      await save('a',11,'arroz con pollo');
      await save('b',12,'Arroz con pollo');
      await save('c',10,'ensalada');
      await save('d',13,'Ensalada');
      await save('e',14,'Sopa');
      expect(own.frequentDishes(),['Arroz con pollo','Ensalada']);
      expect(other.frequentDishes(),isEmpty);
      expect(own.frequentDishes(minimum:3),isEmpty);
      await own.delete('b');
      expect(own.frequentDishes(),['Ensalada']);
    });

    test('frequent dish shortcuts remain optional and never auto-analyze',(){
      final ui=File(
        'lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
      );
      // The core package owns the UI source: no camera is triggered from chips.
      final source=readNutritionPageSource(ui);
      expect(source,contains('_historyRepository.frequentDishes()'));
      expect(source,contains('onPressed:_analyzing?null:()=>_useFrequentDish(dish)'));
      final begin=source.indexOf('void _useFrequentDish(');
      final end=source.indexOf('Widget _buildHistory(',begin);
      final shortcut=source.substring(begin,end);
      expect(shortcut,contains('_photo=null;'));
      expect(shortcut,isNot(contains('_analyzePhoto(')));
      expect(shortcut,isNot(contains('photoPicker(')));
    });

    test('missing IDs cannot create a favorite meal',()async{
      final own=NutritionHistoryRepository(box,ownerId:'uid-a');
      await own.setFavorite('missing',true);
      expect(own.getEntries(),isEmpty);
    });
  });
}
