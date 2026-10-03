import 'package:core/domain/models/coach_assigned_task.dart';

/// Read-only list metadata. Never represents task instructions or completion history.
class CoachProTaskSummary {
  final String id;
  final String relationshipId;
  final String title;
  final String category;
  final CoachAssignedTaskStatus status;
  final DateTime startsOn;
  final DateTime? dueAt;
  final DateTime updatedAt;

  const CoachProTaskSummary({required this.id, required this.relationshipId,
    required this.title, required this.category, required this.status,
    required this.startsOn, this.dueAt, required this.updatedAt});

  factory CoachProTaskSummary.fromJson(Map<String, dynamic> json) {
    final startsOn = DateTime.tryParse('${json['starts_on']}');
    final updatedAt = DateTime.tryParse('${json['updated_at']}');
    final dueAt = json['due_at'] == null ? null : DateTime.tryParse('${json['due_at']}');
    final title = '${json['title'] ?? ''}'.trim();
    final status = CoachAssignedTaskStatus.values.where((s) => s.name == json['status']);
    if (startsOn == null || updatedAt == null || title.isEmpty || status.isEmpty ||
        (json['due_at'] != null && dueAt == null)) {
      throw const FormatException('Invalid task summary');
    }
    return CoachProTaskSummary(id: '${json['id'] ?? ''}',
      relationshipId: '${json['relationship_id'] ?? ''}', title: title,
      category: '${json['category'] ?? ''}', status: status.single,
      startsOn: startsOn, dueAt: dueAt, updatedAt: updatedAt);
  }
}

class CoachProSectionPage<T> {
  final List<T> items;
  final int? totalCount;
  const CoachProSectionPage({this.items = const [], this.totalCount});
}
