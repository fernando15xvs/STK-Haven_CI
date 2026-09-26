import 'package:core/domain/models/nutrition_history_entry.dart';
import 'package:hive/hive.dart';

class NutritionHistoryRepository {
  static const String entryPrefix = 'nutrition_food_history::';
  static const int maxEntries = 100;

  final Box<dynamic> _box;

  NutritionHistoryRepository(this._box);

  List<NutritionHistoryEntry> getEntries() {
    final entries = <NutritionHistoryEntry>[];
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(entryPrefix)) continue;
      final raw = _box.get(key);
      if (raw is! Map) continue;
      try {
        final entry = NutritionHistoryEntry.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (entry.id.isEmpty) continue;
        entries.add(entry);
      } catch (_) {
        // Ignore malformed local entries instead of breaking the screen.
      }
    }
    entries.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
    return entries;
  }

  Future<void> save(NutritionHistoryEntry entry) async {
    if (entry.id.trim().isEmpty) {
      throw ArgumentError.value(entry.id, 'entry.id', 'No puede estar vacío.');
    }
    await _box.put('$entryPrefix${entry.id}', entry.toJson());
    final entries = getEntries();
    if (entries.length <= maxEntries) return;
    for (final stale in entries.skip(maxEntries)) {
      await _box.delete('$entryPrefix${stale.id}');
    }
  }

  Future<void> delete(String id) => _box.delete('$entryPrefix$id');

  Future<void> clear() async {
    final keys = _box.keys
        .whereType<String>()
        .where((key) => key.startsWith(entryPrefix))
        .toList(growable: false);
    await _box.deleteAll(keys);
  }
}
