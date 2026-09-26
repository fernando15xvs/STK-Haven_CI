import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:core/features/faith/data/bible_public_domain_source.dart';

class BibleDatabase {
  static final BibleDatabase instance = BibleDatabase._init();

  BibleDatabase._init();

  final Map<String, List<List<String>>> _books = {};
  final Random _random = Random();

  Future<bool> initializeDatabaseFromInternet(
    Function(String) onStatusChange,
  ) async {
    if (_books.isNotEmpty) return true;

    try {
      final rows = await BiblePublicDomainSource.loadAll(
        onStatusChange: onStatusChange,
      );
      for (final row in rows) {
        final chapters = _books.putIfAbsent(row.book, () => <List<String>>[]);
        while (chapters.length < row.chapter) {
          chapters.add(<String>[]);
        }
        final verses = chapters[row.chapter - 1];
        while (verses.length < row.verse) {
          verses.add('');
        }
        verses[row.verse - 1] = row.text;
      }

      if (_books.isEmpty) {
        throw const FormatException('La fuente bíblica no contiene datos.');
      }
      return true;
    } catch (error) {
      _books.clear();
      debugPrint('Error loading web Bible data: $error');
      return false;
    }
  }

  Future<List<String>> getBooks() async => _books.keys.toList();

  Future<List<int>> getChapters(String book) async {
    final chapters = _books[book] ?? const <List<String>>[];
    return List<int>.generate(chapters.length, (index) => index + 1);
  }

  Future<List<String>> getVersesRaw(String book, int chapter) async {
    final chapters = _books[book];
    if (chapters == null || chapter < 1 || chapter > chapters.length) {
      return const [];
    }
    return List<String>.unmodifiable(chapters[chapter - 1]);
  }

  Future<Map<String, Object?>?> getRandomVerseRaw(
    List<String> keywords,
  ) async {
    final candidates = <Map<String, Object?>>[];

    _books.forEach((book, chapters) {
      for (var chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
        final verses = chapters[chapterIndex];
        for (var verseIndex = 0; verseIndex < verses.length; verseIndex++) {
          final text = verses[verseIndex];
          final matches = keywords.isEmpty ||
              keywords.any(
                (keyword) => text.toLowerCase().contains(keyword.toLowerCase()),
              );
          if (matches) {
            candidates.add({
              'libro': book,
              'capitulo': chapterIndex + 1,
              'versiculo': verseIndex + 1,
              'texto': text,
            });
          }
        }
      }
    });

    if (candidates.isEmpty && keywords.isNotEmpty) {
      return getRandomVerseRaw(const []);
    }
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }
}
