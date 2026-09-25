import 'package:core/domain/models/coach_assigned_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachTaskService {
  final SupabaseClient client;

  const CoachTaskService(this.client);

  Future<String> assignTask({
    required String clientUserId,
    required Map<String, dynamic> taskPayload,
  }) async {
    final response = await client.rpc(
      'stk_assign_coach_task',
      params: <String, dynamic>{
        'p_client_user_id': clientUserId,
        'p_task': taskPayload,
      },
    );
    final id = response?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw const FormatException('Assigned task id was empty.');
    }
    return id;
  }

  Future<List<CoachAssignedTask>> listTasks({
    String? clientUserId,
  }) async {
    dynamic query = client
        .from('stk_coach_tasks')
        .select()
        .order('updated_at', ascending: false);
    if (clientUserId != null && clientUserId.trim().isNotEmpty) {
      query = client
          .from('stk_coach_tasks')
          .select()
          .eq('client_user_id', clientUserId)
          .order('updated_at', ascending: false);
    }

    final response = await query;
    if (response is! List) return const <CoachAssignedTask>[];

    return response
        .whereType<Map>()
        .map(
          (row) => CoachAssignedTask.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .where(
          (task) =>
              task.id.isNotEmpty &&
              task.coachUserId.isNotEmpty &&
              task.clientUserId.isNotEmpty &&
              task.title.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<List<CoachTaskOccurrence>> listOccurrences() async {
    final response = await client
        .from('stk_coach_task_occurrences')
        .select()
        .order('occurrence_date', ascending: false);

    if (response is! List) return const <CoachTaskOccurrence>[];
    return response
        .whereType<Map>()
        .map(
          (row) => CoachTaskOccurrence.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((item) => item.id.isNotEmpty && item.taskId.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<CoachTaskComment>> listComments(String taskId) async {
    final response = await client
        .from('stk_coach_task_comments')
        .select()
        .eq('task_id', taskId)
        .order('created_at');

    if (response is! List) return const <CoachTaskComment>[];
    return response
        .whereType<Map>()
        .map(
          (row) => CoachTaskComment.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((item) => item.id.isNotEmpty && item.taskId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> setOccurrenceStatus({
    required String taskId,
    required DateTime occurrenceDate,
    required CoachTaskOccurrenceStatus status,
    int minutesSpent = 0,
  }) async {
    await client.rpc(
      'stk_set_coach_task_status',
      params: <String, dynamic>{
        'p_task_id': taskId,
        'p_occurrence_date': _dateOnly(occurrenceDate),
        'p_status': status.name,
        'p_minutes_spent': minutesSpent,
      },
    );
  }

  Future<void> addComment({
    required String taskId,
    DateTime? occurrenceDate,
    required String body,
  }) async {
    await client.rpc(
      'stk_add_coach_task_comment',
      params: <String, dynamic>{
        'p_task_id': taskId,
        'p_occurrence_date':
            occurrenceDate == null ? null : _dateOnly(occurrenceDate),
        'p_body': body.trim(),
      },
    );
  }

  Future<void> archiveTask(String taskId) async {
    await client.rpc(
      'stk_archive_coach_task',
      params: <String, dynamic>{'p_task_id': taskId},
    );
  }

  Future<CoachTaskAdherence> getAdherence({
    required String clientUserId,
    int days = 30,
  }) async {
    final response = await client.rpc(
      'stk_get_task_adherence',
      params: <String, dynamic>{
        'p_client_user_id': clientUserId,
        'p_days': days,
      },
    );
    if (response is! Map) {
      throw const FormatException('Task adherence payload was invalid.');
    }
    return CoachTaskAdherence.fromJson(
      Map<String, dynamic>.from(response),
    );
  }
}

String _dateOnly(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
