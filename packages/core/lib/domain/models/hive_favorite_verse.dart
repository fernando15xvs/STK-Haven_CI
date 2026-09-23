import 'package:hive/hive.dart';

part 'hive_favorite_verse.g.dart';

@HiveType(typeId: 12)
class HiveFavoriteVerse extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String book;

  @HiveField(2)
  int chapter;

  @HiveField(3)
  int verse;

  @HiveField(4)
  String text;

  @HiveField(5)
  DateTime savedAt;

  HiveFavoriteVerse({
    required this.id,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.savedAt,
  });
}
