import 'package:core/domain/models/coach_assigned_task.dart';
import 'package:core/features/coach_pro/data/coach_pro_task_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachProTaskCommentsPage {
  final List<CoachTaskComment> items;
  final int totalCount;
  final String coachUserId;
  const CoachProTaskCommentsPage({required this.items, required this.totalCount, required this.coachUserId});
}

class CoachProTaskCommentsService {
  final SupabaseClient client;
  const CoachProTaskCommentsService(this.client);
  Future<void> add({required String relationshipId, required String taskId, required String body}) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.runes.length > 2000) {
      throw const FormatException('Comment length is invalid');
    }
    final result = await client.rpc('stk_add_coach_pro_task_comment', params: {
      'p_relationship_id': relationshipId, 'p_task_id': taskId, 'p_body': trimmed,
    });
    if (result is! String || result.isEmpty) {
      throw const FormatException('Comment acknowledgement missing');
    }
  }

  Future<CoachProTaskCommentsPage> load(CoachProTaskQuery query) async {
    final raw = await client.rpc('stk_list_coach_pro_task_comments', params: {
      'p_relationship_id': query.relationshipId, 'p_task_id': query.taskId,
      'p_limit': 25, 'p_offset': query.offset,
    });
    if (raw is! Map || raw['relationship_id'] != query.relationshipId ||
        raw['task_id'] != query.taskId || raw['items'] is! List ||
        raw['total_count'] is! int || (raw['total_count'] as int) < 0 ||
        raw['coach_user_id'] is! String || (raw['coach_user_id'] as String).isEmpty ||
        raw['client_user_id'] is! String || (raw['client_user_id'] as String).isEmpty) {
      throw const FormatException('Invalid task comments page');
    }
    final items = <CoachTaskComment>[];
    for (final value in raw['items'] as List) {
      if (value is! Map) throw const FormatException('Invalid comment');
      final item = Map<String, dynamic>.from(value);
      if (item['id'] is! String || (item['id'] as String).isEmpty ||
          item['task_id'] != query.taskId ||
          ![raw['coach_user_id'], raw['client_user_id']].contains(item['author_user_id']) ||
          item['body'] is! String || (item['body'] as String).trim().isEmpty ||
          (item['body'] as String).runes.length > 2000 ||
          DateTime.tryParse('${item['created_at']}') == null ||
          (item['occurrence_date'] != null && DateTime.tryParse('${item['occurrence_date']}') == null)) {
        throw const FormatException('Invalid comment scope or content');
      }
      items.add(CoachTaskComment.fromJson(item));
    }
    if (items.length > 25 || items.length > (raw['total_count'] as int)) {
      throw const FormatException('Invalid comments count');
    }
    return CoachProTaskCommentsPage(items: List.unmodifiable(items),
      totalCount: raw['total_count'] as int, coachUserId: raw['coach_user_id'] as String);
  }
}
