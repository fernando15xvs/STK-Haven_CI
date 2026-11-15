import 'dart:io';
import 'package:core/domain/models/nutrition_history_entry.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/data/nutrition_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main(){
  late Directory temp;
  late Box<dynamic> box;
  setUpAll(() async {
    temp=await Directory.systemTemp.createTemp('stk_history_owner_');
    Hive.init(temp.path);
    box=await Hive.openBox<dynamic>('nutrition_owner_qa');
  });
  tearDown(() async => box.clear());
  tearDownAll(() async {
    await Hive.close();
    if(await temp.exists())await temp.delete(recursive:true);
  });
  NutritionHistoryEntry entry(String id)=>NutritionHistoryEntry(
    id:id,analyzedAt:DateTime(2026,11,15),dishHint:'sin aceite',
    estimate:const FoodVisionEstimate(
      dishName:'Comida propia',items:[],
      confidence:FoodVisionConfidence.medium,
      numericNutritionAvailable:true,caloriesLow:400,caloriesHigh:600,
      disclaimer:'Estimación de referencia'),
  );

  test('two authenticated owners never see each other local Food Vision history',()async{
    final ownerA=NutritionHistoryRepository(box,ownerId:'user-A');
    final ownerB=NutritionHistoryRepository(box,ownerId:'user-B');
    final guest=NutritionHistoryRepository(box,ownerId:'guest');
    await ownerA.save(entry('a-food'));
    expect(ownerA.getEntries().single.id,'a-food');
    expect(ownerB.getEntries(),isEmpty);
    expect(guest.getEntries(),isEmpty);
    await ownerB.save(entry('b-food'));
    expect(ownerA.getEntries().map((e)=>e.id),['a-food']);
    expect(ownerB.getEntries().map((e)=>e.id),['b-food']);
    await ownerA.clear();
    expect(ownerB.getEntries().single.id,'b-food');
  });

  test('older unowned history is invisible until explicitly migrated',()async{
    final legacy=NutritionHistoryRepository(box);
    final ownerA=NutritionHistoryRepository(box,ownerId:'user-A');
    final ownerB=NutritionHistoryRepository(box,ownerId:'user-B');
    await legacy.save(entry('old-1'));
    expect(ownerA.hasLegacyEntries,isTrue);
    expect(ownerA.getEntries(),isEmpty);
    expect(ownerB.getEntries(),isEmpty);
    final moved=await ownerA.importLegacyEntries();
    expect(moved,1);
    expect(ownerA.getEntries().single.id,'old-1');
    expect(legacy.getEntries(),isEmpty);
    expect(ownerB.getEntries(),isEmpty);
    expect(ownerB.hasLegacyEntries,isFalse);
  });

  test('legacy collisions cannot overwrite an existing account entry',()async{
    final legacy=NutritionHistoryRepository(box);
    final owner=NutritionHistoryRepository(box,ownerId:'existing');
    await owner.save(entry('same'));
    await legacy.save(entry('same'));
    expect(await owner.importLegacyEntries(),1);
    final ids=owner.getEntries().map((e)=>e.id).toSet();
    expect(ids.length,2);
    expect(ids,contains('same'));
    expect(ids.any((id)=>id.startsWith('legacy_same_')),isTrue);
  });
}
