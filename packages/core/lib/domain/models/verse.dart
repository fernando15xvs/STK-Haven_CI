class Verse {
  final String book;
  final int chapter;
  final int verse;
  final String text;

  const Verse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  String get reference => '$book $chapter:$verse';

  String get id => '$book-$chapter-$verse';
}
