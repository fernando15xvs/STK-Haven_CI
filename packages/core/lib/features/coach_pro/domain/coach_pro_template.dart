/// Minimal Coach Pro template metadata. No prescription or client data in lists.
class CoachProTemplateSummary {
  final String id;
  final String title;
  final int durationWeeks;
  final int routineCount;
  final DateTime createdAt;

  const CoachProTemplateSummary({
    required this.id,
    required this.title,
    required this.durationWeeks,
    required this.routineCount,
    required this.createdAt,
  });

  factory CoachProTemplateSummary.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final weeks = json['duration_weeks'];
    final routines = json['routine_count'];
    final rawDate = json['created_at'];
    final parsedDate = rawDate is String ? DateTime.tryParse(rawDate) : null;
    if (id is! String || id.isEmpty ||
        title is! String || title.trim().isEmpty || title.runes.length > 120 ||
        weeks is! int || weeks < 1 || weeks > 104 ||
        routines is! int || routines < 1 || routines > 20 ||
        parsedDate == null) {
      throw const FormatException('Invalid Coach Pro template');
    }
    return CoachProTemplateSummary(
      id: id, title: title, durationWeeks: weeks,
      routineCount: routines, createdAt: parsedDate,
    );
  }
}

class CoachProTemplatePage {
  final int totalCount;
  final List<CoachProTemplateSummary> items;

  const CoachProTemplatePage({required this.totalCount, required this.items});

  factory CoachProTemplatePage.fromJson(Map<String, dynamic> json, {int limit = 25}) {
    final count = json['total_count'];
    final rawItems = json['items'];
    if (count is! int || count < 0 || count > 100 ||
        rawItems is! List || rawItems.length > limit || rawItems.length > count) {
      throw const FormatException('Invalid Coach Pro template page');
    }
    final items = <CoachProTemplateSummary>[];
    for (final row in rawItems) {
      if (row is! Map) throw const FormatException('Invalid Coach Pro template item');
      items.add(CoachProTemplateSummary.fromJson(Map<String, dynamic>.from(row)));
    }
    return CoachProTemplatePage(totalCount: count, items: List.unmodifiable(items));
  }
}
