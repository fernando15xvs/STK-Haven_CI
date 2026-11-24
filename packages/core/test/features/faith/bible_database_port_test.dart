import 'package:core/features/faith/data/bible_database.dart';
import 'package:test/test.dart';

class _BibleSpy implements BibleDatabaseBackend {
  String? lastBook;
  int? lastChapter;
  int? requestedCount;
  List<String>? requestedKeywords;
  @override
  Future<bool> initializeDatabaseFromInternet(
      Function(String) onStatusChange) async {
    onStatusChange('listo');
    return true;
  }

  @override
  Future<List<String>> getBooks() async => ['Salmos'];

  @override
  Future<List<int>> getChapters(String book) async {
    lastBook = book;
    return [23];
  }

  @override
  Future<List<String>> getVersesRaw(String book, int chapter) async {
    lastBook = book;
    lastChapter = chapter;
    return ['El Señor es mi pastor'];
  }

  @override
  Future<List<Map<String, Object?>>> getRandomVersesRaw(int count) async {
    requestedCount = count;
    return [{'libro': 'Salmos', 'capitulo': 23, 'versiculo': 1, 'texto': 'Verso'}];
  }

  @override
  Future<Map<String, Object?>?> getRandomVerseRaw(
      List<String> keywords) async {
    requestedKeywords = keywords;
    return {'libro': 'Salmos', 'capitulo': 23, 'versiculo': 1, 'texto': 'Verso'};
  }
}

void main() {
  tearDown(() => BibleDatabase.installBackend(null));

  test('Core cannot pretend on-device scripture is initialized without Mobile', () async {
    BibleDatabase.installBackend(null);
    final db = BibleDatabase.instance;
    expect(await db.initializeDatabaseFromInternet((_) {}), false);
    expect(await db.getBooks(), isEmpty);
    expect(await db.getChapters('Salmos'), isEmpty);
    expect(await db.getVersesRaw('Salmos', 23), isEmpty);
    expect(await db.getRandomVersesRaw(4), isEmpty);
    expect(await db.getRandomVerseRaw(['paz']), null);
    expect(() => db.getRandomVersesRaw(49), throwsArgumentError);
  });

  test('same singleton forwards exact verse queries to the Mobile backend', () async {
    final spy = _BibleSpy();
    final db = BibleDatabase.instance;
    BibleDatabase.installBackend(spy);
    String? status;
    expect(await db.initializeDatabaseFromInternet((v) => status = v), true);
    expect(status, 'listo');
    expect(await db.getBooks(), ['Salmos']);
    expect(await db.getChapters('Salmos'), [23]);
    expect((await db.getVersesRaw('Salmos', 23)).single, 'El Señor es mi pastor');
    expect(spy.lastBook, 'Salmos');
    expect(spy.lastChapter, 23);
    expect((await db.getRandomVersesRaw(3)).single['libro'], 'Salmos');
    expect(spy.requestedCount, 3);
    expect((await db.getRandomVerseRaw(['paz']))!['capitulo'], 23);
    expect(spy.requestedKeywords, ['paz']);
  });
}
