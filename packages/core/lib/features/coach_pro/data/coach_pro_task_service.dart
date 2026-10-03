import 'package:core/domain/models/coach_assigned_task.dart';
import 'package:core/domain/models/habit_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CoachProTaskQuery = ({String relationshipId, String taskId, int offset});

class CoachProTaskPage {
  final CoachAssignedTask task;
  final List<CoachTaskOccurrence> occurrences;
  final int totalCount;
  const CoachProTaskPage({required this.task, required this.occurrences, required this.totalCount});
}

class CoachProTaskService {
  final SupabaseClient client;
  const CoachProTaskService(this.client);

  Future<CoachProTaskPage> load(CoachProTaskQuery query) async {
    final raw = await client.rpc('stk_get_coach_pro_task_page', params: {
      'p_relationship_id': query.relationshipId, 'p_task_id': query.taskId,
      'p_limit': 25, 'p_offset': query.offset,
    });
    if (raw is! Map || raw['task'] is! Map || raw['items'] is! List ||
        raw['total_count'] is! int || (raw['total_count'] as int) < 0) {
      throw const FormatException('Invalid task page');
    }
    final json = Map<String, dynamic>.from(raw['task'] as Map);
    if (json['id'] != query.taskId || json['relationship_id'] != query.relationshipId ||
        '${json['client_user_id'] ?? ''}'.isEmpty || '${json['coach_user_id'] ?? ''}'.isEmpty ||
        '${json['title'] ?? ''}'.trim().isEmpty ||
        !CoachAssignedTaskStatus.values.any((s) => s.name == json['status']) ||
        !HabitTaskType.values.any((s) => s.name == json['task_type']) ||
        !HabitRecurrenceType.values.any((s) => s.name == json['recurrence_type']) ||
        !_minutes(json['target_minutes']) || json['weekdays'] is! List) {
      throw const FormatException('Invalid task scope');
    }
    for (final key in ['starts_on', 'created_at', 'updated_at']) {
      _date(json[key]);
    }
    for (final key in ['due_at', 'ends_on']) {
      if (json[key] != null) _date(json[key]);
    }
    if ((json['weekdays'] as List).any((v) => v is! int || v < 1 || v > 7)) {
      throw const FormatException('Invalid task schedule');
    }
    final task = CoachAssignedTask.fromJson(json);
    final items = <CoachTaskOccurrence>[];
    for (final rawItem in raw['items'] as List) {
      final item = Map<String, dynamic>.from(rawItem as Map);
      if ('${item['id'] ?? ''}'.isEmpty || item['task_id'] != task.id ||
          item['client_user_id'] != task.clientUserId || !_minutes(item['minutes_spent']) ||
          !CoachTaskOccurrenceStatus.values.any((s) => s.name == item['status'])) {
        throw const FormatException('Invalid task occurrence scope');
      }
      _date(item['occurrence_date']);
      _date(item['created_at']);
      if (item['completed_at'] != null) _date(item['completed_at']);
      items.add(CoachTaskOccurrence.fromJson(item));
    }
    return CoachProTaskPage(task: task, occurrences: List.unmodifiable(items),
      totalCount: raw['total_count'] as int);
  }
}
bool _minutes(dynamic value) => value is int && value >= 0 && value <= 1440;
void _date(dynamic value) {
  if (DateTime.tryParse('$value') == null) throw const FormatException('Invalid task date');
}
