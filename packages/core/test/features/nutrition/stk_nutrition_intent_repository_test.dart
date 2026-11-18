import 'dart:io';

import 'package:core/features/nutrition/application/stk_age_aware_nutrition_plans.dart';
import 'package:core/features/nutrition/data/stk_nutrition_intent_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late Box<dynamic> metadata;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('stk_intent_scope_');
    Hive.init(directory.path);
    metadata = await Hive.openBox<dynamic>('intent_scope');
  });
  tearDown(() async => metadata.clear());
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('reading missing preference never writes a default or an adult grant', () {
    final repo = StkNutritionIntentRepository(metadata, ownerId: 'alice');
    expect(repo.read(), isNull);
    expect(metadata.isEmpty, isTrue);
  });

  test('each account and guest is isolated across restarts', () async {
    final alice = StkNutritionIntentRepository(metadata, ownerId: 'alice');
    final bob = StkNutritionIntentRepository(metadata, ownerId: 'bob');
    final guest = StkNutritionIntentRepository(metadata, ownerId: null);
    await alice.save(StkNutritionIntent.volume);
    await guest.save(StkNutritionIntent.deficit);
    expect(bob.read(), isNull);
    expect(alice.read(), StkNutritionIntent.volume);
    expect(guest.read(), StkNutritionIntent.deficit);
    await bob.save(StkNutritionIntent.maintenance);
    expect(StkNutritionIntentRepository(metadata, ownerId: 'alice').read(),
        StkNutritionIntent.volume);
    expect(StkNutritionIntentRepository(metadata, ownerId: 'bob').read(),
        StkNutritionIntent.maintenance);
    expect(StkNutritionIntentRepository(metadata, ownerId: null).read(),
        StkNutritionIntent.deficit);
    await alice.clear();
    expect(alice.read(), isNull);
    expect(bob.read(), StkNutritionIntent.maintenance);
    expect(guest.read(), StkNutritionIntent.deficit);
  });

  test('corrupt and future records fail closed without rewriting history', () async {
    final repo = StkNutritionIntentRepository(metadata, ownerId: 'alice');
    final key = repo.storageKey;
    for (final payload in [
      'invalid',
      {'version': 2, 'scope': 'account:alice', 'intent': 'deficit'},
      {'version': 1, 'scope': 'account:bob', 'intent': 'volume'},
      {'version': 1, 'scope': 'account:alice', 'intent': 'fake'},
    ]) {
      await metadata.put(key, payload);
      expect(repo.read(), isNull);
      expect(metadata.get(key), payload);
    }
  });

  test('selection only edits its own metadata key', () async {
    await metadata.put('stk_nutrition_goal_plan_v1_alice',
        {'version': 3, 'important': 'untouched'});
    await metadata.put('hydration_preferences', {'water': 2500});
    final before = metadata.keys.toSet();
    await StkNutritionIntentRepository(metadata, ownerId: 'alice')
        .save(StkNutritionIntent.deficit);
    expect(metadata.keys.toSet().difference(before).length, 1);
    expect(metadata.get('stk_nutrition_goal_plan_v1_alice'),
        {'version': 3, 'important': 'untouched'});
    expect(metadata.get('hydration_preferences'), {'water': 2500});
  });
}
