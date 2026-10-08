enum CoachProAgendaStatus { unrecorded, completed, skipped }

class CoachProAgendaItem {
  final String taskId;
  final String title;
  final DateTime dueOn;
  final String taskType;
  final int targetMinutes;
  final CoachProAgendaStatus status;
  final int? minutesSpent;

  const CoachProAgendaItem({
    required this.taskId,
    required this.title,
    required this.dueOn,
    required this.taskType,
    required this.targetMinutes,
    required this.status,
    required this.minutesSpent,
  });

  factory CoachProAgendaItem.fromJson(Map<String, dynamic> json) {
    final id = json['task_id'];
    final title = json['title'];
    final day = json['due_on'];
    final type = json['task_type'];
    final target = json['target_minutes'];
    final rawStatus = json['status'];
    final minutes = json['minutes_spent'];
    if (id is! String || id.isEmpty ||
        title is! String || title.trim().isEmpty || title.runes.length > 160 ||
        day is! String || !_isDateOnly(day) ||
        type is! String || !const {
          'checklist', 'readingTimer', 'studySession', 'reflection', 'custom'
        }.contains(type) ||
        target is! int || target < 0 || target > 1440 ||
        (rawStatus != null && rawStatus != 'completed' &&
          rawStatus != 'skipped') ||
        (rawStatus == null && minutes != null) ||
        (rawStatus != null && (minutes is! int ||
          minutes < 0 || minutes > 1440))) {
      throw const FormatException('Invalid recurring task agenda item');
    }
    return CoachProAgendaItem(
      taskId: id,
      title: title,
      dueOn: DateTime.parse(day),
      taskType: type,
      targetMinutes: target,
      status: rawStatus == null ? CoachProAgendaStatus.unrecorded
        : rawStatus == 'completed'
          ? CoachProAgendaStatus.completed : CoachProAgendaStatus.skipped,
      minutesSpent: minutes as int?,
    );
  }
}

class CoachProAgendaPage {
  final String relationshipId;
  final DateTime startOn;
  final int days;
  final int totalCount;
  final List<CoachProAgendaItem> items;

  const CoachProAgendaPage({
    required this.relationshipId,
    required this.startOn,
    required this.days,
    required this.totalCount,
    required this.items,
  });

  factory CoachProAgendaPage.fromJson(
    Map<String, dynamic> json, {
    required String expectedRelationshipId,
    int pageSize = 25,
  }) {
    final relationship = json['relationship_id'];
    final date = json['start_on'];
    final days = json['days'];
    final total = json['total_count'];
    final list = json['items'];
    if (relationship is! String || relationship != expectedRelationshipId ||
        date is! String || !_isDateOnly(date) ||
        days is! int || days < 1 || days > 14 ||
        total is! int || total < 0 || total > 100000 ||
        list is! List || list.length > pageSize || list.length > total) {
      throw const FormatException('Invalid recurring task agenda page');
    }
    final start = DateTime.parse(date);
    final end = start.add(Duration(days: days - 1));
    final items = <CoachProAgendaItem>[];
    for (final entry in list) {
      if (entry is! Map) {
        throw const FormatException('Invalid recurring task agenda entry');
      }
      final item = CoachProAgendaItem.fromJson(
        Map<String, dynamic>.from(entry));
      if (item.dueOn.isBefore(start) || item.dueOn.isAfter(end)) {
        throw const FormatException('Task schedule outside requested range');
      }
      items.add(item);
    }
    return CoachProAgendaPage(
      relationshipId: relationship,
      startOn: start,
      days: days,
      totalCount: total,
      items: List.unmodifiable(items),
    );
  }
}
bool _isDateOnly(String value) =>
    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
    DateTime.tryParse(value) != null;
