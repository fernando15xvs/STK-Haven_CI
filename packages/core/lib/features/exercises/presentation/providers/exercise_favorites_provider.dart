import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/exercises/data/exercise_favorites_repository.dart';

final exerciseFavoritesRepositoryProvider = Provider<ExerciseFavoritesRepository>((ref) {
  final box = Hive.box(HiveBoxes.metadata);
  return ExerciseFavoritesRepository(box);
});

final exerciseFavoriteIdsProvider =
    NotifierProvider<ExerciseFavoriteIdsNotifier, Set<String>>(
  ExerciseFavoriteIdsNotifier.new,
);

class ExerciseFavoriteIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return ref.read(exerciseFavoritesRepositoryProvider).getFavoriteIds();
  }

  bool isFavorite(String exerciseId) => state.contains(exerciseId);

  Future<void> toggleFavorite(String exerciseId) async {
    final normalizedId = exerciseId.trim();
    if (normalizedId.isEmpty) return;

    final next = {...state};
    if (!next.add(normalizedId)) {
      next.remove(normalizedId);
    }

    await ref
        .read(exerciseFavoritesRepositoryProvider)
        .saveFavoriteIds(next);
    state = Set<String>.unmodifiable(next);
  }

  Future<void> setFavorite(String exerciseId, bool favorite) async {
    final normalizedId = exerciseId.trim();
    if (normalizedId.isEmpty) return;

    final next = {...state};
    if (favorite) {
      next.add(normalizedId);
    } else {
      next.remove(normalizedId);
    }

    await ref
        .read(exerciseFavoritesRepositoryProvider)
        .saveFavoriteIds(next);
    state = Set<String>.unmodifiable(next);
  }
}
