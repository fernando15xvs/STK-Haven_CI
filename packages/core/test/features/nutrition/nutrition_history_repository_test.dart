import 'dart:io';

import 'package:core/domain/models/nutrition_history_entry.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/nutrition/data/nutrition_history_repository.dart';
import 'package:test/test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> box;

  setUpAll(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('stk_nutrition_history_');
    Hive.init(tempDirectory.path);
    box = await Hive.openBox<dynamic>('nutrition_history_test');
  });

  tearDown(() async {
    await box.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  FoodVisionEstimate estimate(String dish) => FoodVisionEstimate(
        dishName: dish,
        items: const <FoodVisionItem>[],
        confidence: FoodVisionConfidence.medium,
        numericNutritionAvailable: false,
        disclaimer: 'Estimación visual.',
      );

  test('history is local JSON-compatible data and does not store image bytes',
      () async {
    final repository = NutritionHistoryRepository(box);
    final entry = NutritionHistoryEntry(
      id: 'one',
      analyzedAt: DateTime(2026, 9, 26, 12),
      dishHint: 'sin salsa',
      estimate: estimate('Plato mixto'),
    );

    await repository.save(entry);

    final stored = box.get(
      '${NutritionHistoryRepository.entryPrefix}one',
    ) as Map;
    expect(stored.containsKey('image'), isFalse);
    expect(stored.containsKey('imageBytes'), isFalse);
    expect(repository.getEntries().single.estimate.dishName, 'Plato mixto');
  });

  test('consumption is explicit, reversible and isolated by owner',() async {
    final first=NutritionHistoryRepository(box,ownerId:'a');
    final second=NutritionHistoryRepository(box,ownerId:'b');
    final entry=NutritionHistoryEntry(id:'same',analyzedAt:DateTime(2026,11,27),
      dishHint:'',estimate:estimate('Plato'));
    await first.save(entry);
    await second.save(entry);
    expect(first.getEntries().single.consumedAt,isNull);
    final date=DateTime(2026,11,27,13);
    await first.setConsumption('same',date);
    await first.setFavorite('same',true);
    expect(first.getEntries().single.consumedAt,date);
    expect(second.getEntries().single.consumedAt,isNull);
    await first.setConsumption('same',null);
    expect(first.getEntries().single.consumedAt,isNull);
  });

  test('entries can be deleted individually and cleared', () async {
    final repository = NutritionHistoryRepository(box);
    for (final id in ['a', 'b']) {
      await repository.save(
        NutritionHistoryEntry(
          id: id,
          analyzedAt: DateTime(2026, 9, 26, id == 'a' ? 10 : 11),
          dishHint: '',
          estimate: estimate(id),
        ),
      );
    }

    await repository.delete('a');
    expect(repository.getEntries().map((e) => e.id), ['b']);

    await repository.clear();
    expect(repository.getEntries(), isEmpty);
  });

  test('malformed local rows do not break valid history', () async {
    final repository = NutritionHistoryRepository(box);
    await repository.save(
      NutritionHistoryEntry(
        id: 'valid',
        analyzedAt: DateTime(2026, 9, 26),
        dishHint: '',
        estimate: estimate('válido'),
      ),
    );
    await box.put(
      '${NutritionHistoryRepository.entryPrefix}bad',
      'not-a-map',
    );

    expect(repository.getEntries().map((e) => e.id), ['valid']);
  });
}
