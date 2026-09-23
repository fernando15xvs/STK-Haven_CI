import 'package:core/domain/models/verse.dart';
import 'package:core/features/faith/data/bible_database.dart';


class BibleRepository {
  final BibleDatabase database;

  BibleRepository(this.database);

  Future<List<String>> getBooks() {
    return database.getBooks();
  }

  Future<List<int>> getChapters(String book) {
    return database.getChapters(book);
  }

  Future<List<Verse>> getVerses(String book, int chapter) async {
    final rawVerses = await database.getVersesRaw(book, chapter);
    return rawVerses.asMap().entries.map((e) {
      return Verse(
        book: book,
        chapter: chapter,
        verse: e.key + 1,
        text: e.value,
      );
    }).toList();
  }

  List<String> _getKeywords(String mood) {
    switch (mood) {
      case "Triste":
        return ["consuelo", "llanto", "angustia", "tristeza"];
      case "Agradecido":
        return ["gracias", "alabanza", "gozo", "gratitud"];
      case "Ansioso":
        return ["miedo", "refugio", "paz", "temor", "ansiedad"];
      case "Esperanza":
        return ["esperanza", "futuro", "fe", "promesa"];
      case "Enojado":
        return ["ira", "enojo", "paciencia", "perdón"];
      case "Cansado":
        return ["fuerzas", "descanso", "fatiga"];
      default:
        return [];
    }
  }

  Future<Verse?> getRandomVerse({String mood = 'General'}) async {
    final keywords =
        mood == 'General' ? const <String>[] : _getKeywords(mood);
    final row = await database.getRandomVerseRaw(keywords);

    if (row == null) return null;

    return Verse(
      book: row['libro'] as String,
      chapter: row['capitulo'] as int,
      verse: row['versiculo'] as int,
      text: row['texto'] as String,
    );
  }
}
