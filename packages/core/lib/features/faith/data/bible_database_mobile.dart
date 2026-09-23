import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

class BibleDatabase {
  static final BibleDatabase instance = BibleDatabase._init();
  static Database? _database;

  BibleDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('biblia_v4.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE versiculos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        libro TEXT,
        capitulo INTEGER,
        versiculo INTEGER,
        texto TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_libro ON versiculos(libro)');
    await db.execute('CREATE INDEX idx_libro_capitulo ON versiculos(libro, capitulo)');
  }

  Future<bool> initializeDatabaseFromInternet(
    Function(String) onStatusChange,
  ) async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM versiculos'),
    );

    if (count != null && count > 0) return true;

    onStatusChange('Descargando Biblia...');
    try {
      final url = Uri.parse(
        'https://cdn.jsdelivr.net/gh/dscottpi/bibles@master/RVR1960%20-%20Spanish.json',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.body.trim().isEmpty) {
        throw Exception('Error descarga (${response.statusCode})');
      }

      onStatusChange('Guardando datos...');
      final dynamic decoded = await compute(jsonDecode, response.body);
      final jsonList = <dynamic>[];

      if (decoded is List) {
        jsonList.addAll(decoded);
      } else if (decoded is Map) {
        decoded.forEach(
          (key, value) => jsonList.add({'book': key, 'chapters': value}),
        );
      } else {
        throw const FormatException('Formato de Biblia no reconocido.');
      }

      var batch = db.batch();
      int batchCount = 0;
      for (final bookData in jsonList) {
        final String libro = bookData['book'];
        final dynamic chaptersRaw = bookData['chapters'];
        final chapters = <dynamic>[];

        if (chaptersRaw is Map) {
          final keys = chaptersRaw.keys
              .map((key) => int.tryParse(key.toString()) ?? 0)
              .toList()
            ..sort();
          for (final key in keys) {
            chapters.add(chaptersRaw[key.toString()]);
          }
        } else if (chaptersRaw is List) {
          chapters.addAll(chaptersRaw);
        }

        for (int chapterIndex = 0;
            chapterIndex < chapters.length;
            chapterIndex++) {
          final dynamic versesRaw = chapters[chapterIndex];
          final verses = <String>[];

          if (versesRaw is Map) {
            final keys = versesRaw.keys
                .map((key) => int.tryParse(key.toString()) ?? 0)
                .toList()
              ..sort();
            for (final key in keys) {
              verses.add(versesRaw[key.toString()].toString());
            }
          } else if (versesRaw is List) {
            verses.addAll(versesRaw.map((verse) => verse.toString()));
          }

          for (int verseIndex = 0;
              verseIndex < verses.length;
              verseIndex++) {
            batch.insert('versiculos', {
              'libro': libro,
              'capitulo': chapterIndex + 1,
              'versiculo': verseIndex + 1,
              'texto': verses[verseIndex],
            });
            batchCount++;
            if (batchCount >= 1000) {
              await batch.commit(continueOnError: true);
              batch = db.batch();
              batchCount = 0;

              // Yield between chunks so a first-run Bible import cannot occupy
              // the UI isolate continuously while the user is navigating.
              await Future<void>.delayed(Duration.zero);
            }
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit(continueOnError: true);
      }
      debugPrint('Database initialized');
      return true;
    } catch (e) {
      debugPrint('Error opening database: $e');
      return false;
    }
  }

  Future<List<String>> getBooks() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT libro FROM versiculos ORDER BY id ASC',
    );
    return result.map((e) => e['libro'] as String).toList();
  }

  Future<List<int>> getChapters(String libro) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT capitulo FROM versiculos WHERE libro = ? ORDER BY capitulo ASC',
      [libro],
    );
    return result.map((e) => e['capitulo'] as int).toList();
  }

  Future<List<String>> getVersesRaw(String libro, int capitulo) async {
    final db = await instance.database;
    final result = await db.query(
      'versiculos',
      columns: ['texto'],
      where: 'libro = ? AND capitulo = ?',
      whereArgs: [libro, capitulo],
      orderBy: 'versiculo ASC',
    );
    return result.map((e) => e['texto'] as String).toList();
  }

  Future<Map<String, Object?>?> getRandomVerseRaw(
    List<String> keywords,
  ) async {
    final db = await instance.database;
    List<Map<String, Object?>> result;

    if (keywords.isEmpty) {
      result = await db.rawQuery(
        'SELECT * FROM versiculos ORDER BY RANDOM() LIMIT 1',
      );
    } else {
      final whereClause =
          List.filled(keywords.length, 'LOWER(texto) LIKE ?').join(' OR ');
      final arguments =
          keywords.map((keyword) => '%${keyword.toLowerCase()}%').toList();
      result = await db.rawQuery(
        'SELECT * FROM versiculos WHERE $whereClause ORDER BY RANDOM() LIMIT 1',
        arguments,
      );

      if (result.isEmpty) {
        result = await db.rawQuery(
          'SELECT * FROM versiculos ORDER BY RANDOM() LIMIT 1',
        );
      }
    }

    return result.isEmpty ? null : result.first;
  }
}
