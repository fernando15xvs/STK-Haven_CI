import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/domain/models/hive_favorite_verse.dart';
import 'package:core/domain/models/verse.dart';

class FavoritesNotifier extends Notifier<List<HiveFavoriteVerse>> {
  @override
  List<HiveFavoriteVerse> build() {
    final box = Hive.box<HiveFavoriteVerse>(HiveBoxes.favoriteVerses);
    return box.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  void toggleFavorite(Verse verse) {
    final box = Hive.box<HiveFavoriteVerse>(HiveBoxes.favoriteVerses);
    final existingIndex = state.indexWhere((v) => v.id == verse.id);

    if (existingIndex >= 0) {
      // Remove
      final fav = state[existingIndex];
      fav.delete();
    } else {
      // Add
      final fav = HiveFavoriteVerse(
        id: verse.id,
        book: verse.book,
        chapter: verse.chapter,
        verse: verse.verse,
        text: verse.text,
        savedAt: DateTime.now(),
      );
      box.add(fav);
    }
    
    // Update state
    state = box.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  bool isFavorite(String id) {
    return state.any((v) => v.id == id);
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, List<HiveFavoriteVerse>>(FavoritesNotifier.new);
