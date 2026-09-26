import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:core/features/faith/data/bible_public_domain_source.dart';

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

    try {
      final rows = await BiblePublicDomainSource.loadAll(
        onStatusChange: onStatusChange,
      );
      onStatusChange(
        'Guardando ${BiblePublicDomainSource.translationName}…',
      );

      var batch = db.batch();
      var batchCount = 0;
      for (final row in rows) {
        batch.insert('versiculos', {
          'libro': row.book,
          'capitulo': row.chapter,
          'versiculo': row.verse,
          'texto': row.text,
        });
        batchCount++;
        if (batchCount >= 1000) {
          await batch.commit(continueOnError: true);
          batch = db.batch();
          batchCount = 0;
          await Future<void>.delayed(Duration.zero);
        }
      }

      if (batchCount > 0) {
        await batch.commit(continueOnError: true);
      }
      debugPrint(
        'Bible database initialized with '
        '${BiblePublicDomainSource.translationName}',
      );
      return true;
    } catch (error) {
      debugPrint('Error opening Bible database: $error');
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
