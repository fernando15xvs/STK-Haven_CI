import 'dart:convert';

import 'package:http/http.dart' as http;

class BibleVerseRecord {
  final String book;
  final int chapter;
  final int verse;
  final String text;

  const BibleVerseRecord({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });
}

class BiblePublicDomainSource {
  static const String translationName = 'Reina-Valera 1909';
  static const String sourceName = 'BibleAquifer/ReinaValera1909';
  static const String sourceTag = 'v2026-09-18';
  static const String licenseName = 'Public Domain / CC0';
  static const String licenseUrl =
      'https://creativecommons.org/public-domain/cc0/';
  static const String sourceUrl =
      'https://github.com/BibleAquifer/ReinaValera1909';

  static const String _rawBase =
      'https://raw.githubusercontent.com/BibleAquifer/'
      'ReinaValera1909/v2026-09-18/spa/json';

  const BiblePublicDomainSource._();

  static Future<List<BibleVerseRecord>> loadAll({
    http.Client? client,
    void Function(String status)? onStatusChange,
  }) async {
    final ownClient = client == null;
    final httpClient = client ?? http.Client();
    final result = <BibleVerseRecord>[];

    try {
      for (var start = 1; start <= 66; start += 6) {
        final end = (start + 5).clamp(1, 66);
        onStatusChange?.call(
          'Preparando $translationName · libros $start-$end de 66…',
        );
        final futures = <Future<List<BibleVerseRecord>>>[];
        for (var book = start; book <= end; book++) {
          futures.add(_loadBook(httpClient, book));
        }
        final groups = await Future.wait(futures);
        for (final group in groups) {
          result.addAll(group);
        }
      }
      return result;
    } finally {
      if (ownClient) httpClient.close();
    }
  }

  static Future<List<BibleVerseRecord>> _loadBook(
    http.Client client,
    int bookNumber,
  ) async {
    final id = bookNumber.toString().padLeft(2, '0');
    final uri = Uri.parse('$_rawBase/$id.content.json');
    final res = await client.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200 || res.body.trim().isEmpty) {
      throw StateError(
        'No se pudo cargar $translationName ($id, HTTP ${res.statusCode}).',
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List) {
      throw const FormatException('Formato bíblico no reconocido.');
    }

    final rows = <BibleVerseRecord>[];
    for (final raw in decoded.whereType<Map>()) {
      final row = parseEntry(Map<String, dynamic>.from(raw));
      if (row != null) rows.add(row);
    }
    if (rows.isEmpty) {
      throw FormatException('El libro $id no contiene versículos válidos.');
    }
    return rows;
  }

  static BibleVerseRecord? parseEntry(Map<String, dynamic> raw) {
    final title = raw['title']?.toString().trim() ?? '';
    final content = raw['content']?.toString() ?? '';
    final match = RegExp(r'^(.+?)\s+(\d+):(\d+)$').firstMatch(title);
    if (match == null) return null;

    final book = match.group(1)!.trim();
    final chapter = int.tryParse(match.group(2)!);
    final verse = int.tryParse(match.group(3)!);
    if (book.isEmpty || chapter == null || verse == null) return null;

    final text = _plainText(content);
    if (text.isEmpty) return null;
    return BibleVerseRecord(
      book: book,
      chapter: chapter,
      verse: verse,
      text: text,
    );
  }

  static String _plainText(String html) {
    var value = html
        .replaceAll(RegExp(r'<sup[^>]*>.*?</sup>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }
}
