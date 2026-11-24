/// Repository-level API for public-domain scripture, with no Flutter/SQLite.
abstract class BibleDatabaseBackend {
  Future<bool> initializeDatabaseFromInternet(
    Function(String) onStatusChange,
  );
  Future<List<String>> getBooks();
  Future<List<int>> getChapters(String book);
  Future<List<String>> getVersesRaw(String book, int chapter);
  Future<List<Map<String, Object?>>> getRandomVersesRaw(int count);
  Future<Map<String, Object?>?> getRandomVerseRaw(List<String> keywords);
}

/// Holds no native database; Mobile installs the existing on-device SQLite backend.
///
/// Production keeps the same `biblia_v4.db` file and table definitions.
class BibleDatabase {
  static final BibleDatabase instance = BibleDatabase._();
  static BibleDatabaseBackend? _backend;

  BibleDatabase._();

  static void installBackend(BibleDatabaseBackend? backend) {
    _backend = backend;
  }

  Future<bool> initializeDatabaseFromInternet(
    Function(String) onStatusChange,
  ) => _backend?.initializeDatabaseFromInternet(onStatusChange)
      ?? Future<bool>.value(false);

  Future<List<String>> getBooks() =>
      _backend?.getBooks() ?? Future<List<String>>.value(const []);

  Future<List<int>> getChapters(String book) =>
      _backend?.getChapters(book) ?? Future<List<int>>.value(const []);

  Future<List<String>> getVersesRaw(String book, int chapter) =>
      _backend?.getVersesRaw(book, chapter)
      ?? Future<List<String>>.value(const []);

  Future<List<Map<String, Object?>>> getRandomVersesRaw(int count) {
    if (count < 1 || count > 48) throw ArgumentError.value(count);
    return _backend?.getRandomVersesRaw(count)
        ?? Future<List<Map<String, Object?>>>.value(const []);
  }

  Future<Map<String, Object?>?> getRandomVerseRaw(
    List<String> keywords,
  ) => _backend?.getRandomVerseRaw(keywords)
      ?? Future<Map<String, Object?>?>.value();
}
