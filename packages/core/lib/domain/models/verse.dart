class Verse {
  final String book;
  final int chapter;
  final int verse;
  final int? endVerse;
  final String text;

  /// These are editorial notes, never represented as biblical text.
  final String? explanation;
  final String? reflectionQuestion;

  const Verse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    this.endVerse,
    this.explanation,
    this.reflectionQuestion,
  });

  String get reference => endVerse != null && endVerse! > verse
      ? '$book $chapter:$verse-$endVerse'
      : '$book $chapter:$verse';

  String get id => '$book-$chapter-$verse-${endVerse ?? verse}';
}
