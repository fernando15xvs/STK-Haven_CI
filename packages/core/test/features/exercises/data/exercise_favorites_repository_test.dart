import 'dart:io';

import 'package:core/features/exercises/data/exercise_favorites_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> box;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp('stk_haven_favorites_');
    Hive.init(tempDirectory.path);
    box = await Hive.openBox<dynamic>('exercise_favorites_test');
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

  group('ExerciseFavoritesRepository', () {
    test('returns an empty set when no favorites are stored', () {
      final repository = ExerciseFavoritesRepository(box);

      expect(repository.getFavoriteIds(), isEmpty);
    });

    test('normalizes stored favorite exercise ids', () async {
      await box.put(
        ExerciseFavoritesRepository.storageKey,
        ['bench', ' bench ', '', 'row', 'bench', 42],
      );
      final repository = ExerciseFavoritesRepository(box);

      expect(repository.getFavoriteIds(), {'bench', 'row'});
    });

    test('stores a deterministic unique favorite id list', () async {
      final repository = ExerciseFavoritesRepository(box);

      await repository.saveFavoriteIds({'row', 'bench', ' '});

      expect(
        box.get(ExerciseFavoritesRepository.storageKey),
        ['bench', 'row'],
      );
      expect(repository.getFavoriteIds(), {'bench', 'row'});
    });
  });
}
