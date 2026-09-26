import 'package:hive/hive.dart';

class StudyResourceBookmarkRepository {
  static const String key = 'study_resource_bookmarks_v1';
  final Box<dynamic> _box;

  StudyResourceBookmarkRepository(this._box);

  Set<String> getBookmarks() {
    final raw = _box.get(key);
    if (raw is! List) return <String>{};
    return raw.map((value) => value.toString()).where((id) => id.isNotEmpty).toSet();
  }

  Future<void> setBookmarked(String resourceId, bool bookmarked) async {
    final next = getBookmarks();
    if (bookmarked) {
      next.add(resourceId);
    } else {
      next.remove(resourceId);
    }
    final values = next.toList()..sort();
    await _box.put(key, values);
  }
}
