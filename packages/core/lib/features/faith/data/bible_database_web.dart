import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BibleDatabase {
  static final BibleDatabase instance = BibleDatabase._init();

  BibleDatabase._init();

  final Map<String, List<List<String>>> _books = {};
  final Random _random = Random();

  Future<bool> initializeDatabaseFromInternet(
    Function(String) onStatusChange,
  ) async {
    if (_books.isNotEmpty) return true;

    onStatusChange('Descargando Biblia...');
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://cdn.jsdelivr.net/gh/dscottpi/bibles@master/RVR1960%20-%20Spanish.json',
            ),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200 || response.body.trim().isEmpty) {
        throw Exception('Error descarga (${response.statusCode})');
      }

      onStatusChange('Preparando datos...');
      final decoded = json.decode(response.body);
      _parse(decoded);

      if (_books.isEmpty) {
        throw const FormatException('La Biblia descargada no contiene datos.');
      }

      return true;
    } catch (error) {
      _books.clear();
      debugPrint('Error loading web Bible data: $error');
      return false;
    }
  }

  void _parse(dynamic decoded) {
    final entries = <MapEntry<String, dynamic>>[];

    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map && item['book'] != null) {
          entries.add(MapEntry(item['book'].toString(), item['chapters']));
        }
      }
    } else if (decoded is Map) {
      decoded.forEach(
        (key, value) => entries.add(MapEntry(key.toString(), value)),
      );
    } else {
      throw const FormatException('Formato de Biblia no reconocido.');
    }

    for (final entry in entries) {
      final chapters = <List<String>>[];
      final rawChapters = entry.value;

      if (rawChapters is List) {
        for (final chapter in rawChapters) {
          chapters.add(_parseVerses(chapter));
        }
      } else if (rawChapters is Map) {
        final keys = rawChapters.keys.toList()
          ..sort(
            (a, b) => (int.tryParse(a.toString()) ?? 0)
                .compareTo(int.tryParse(b.toString()) ?? 0),
          );
        for (final key in keys) {
          chapters.add(_parseVerses(rawChapters[key]));
        }
      }

      if (chapters.isNotEmpty) {
        _books[entry.key] = chapters;
      }
    }
  }

  List<String> _parseVerses(dynamic rawVerses) {
    if (rawVerses is List) {
      return rawVerses.map((verse) => verse.toString()).toList();
    }

    if (rawVerses is Map) {
      final keys = rawVerses.keys.toList()
        ..sort(
          (a, b) => (int.tryParse(a.toString()) ?? 0)
              .compareTo(int.tryParse(b.toString()) ?? 0),
        );
      return keys.map((key) => rawVerses[key].toString()).toList();
    }

    return const [];
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
