import 'package:hive_flutter/hive_flutter.dart';

class ExerciseFavoritesRepository {
  static const String storageKey = 'favorite_exercise_ids';

  final Box<dynamic> _box;

  ExerciseFavoritesRepository(this._box);

  Set<String> getFavoriteIds() {
    final raw = _box.get(storageKey);
    if (raw is! Iterable) return <String>{};

    return raw
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> saveFavoriteIds(Set<String> ids) async {
    final normalized = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

    await _box.put(storageKey, normalized);
  }
}
