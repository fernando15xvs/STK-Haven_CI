import 'package:core/domain/models/coach_client_progress.dart';
import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/features/coach_pro/domain/coach_pro_task_summary.dart';
import 'package:core/domain/models/coach_checkin.dart';
import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachProCheckinPage {
  final List<CoachCheckin> items;
  final int? totalCount;
  const CoachProCheckinPage({this.items = const [], this.totalCount});
}

class CoachProClientDetailService {
  final SupabaseClient client;
  const CoachProClientDetailService(this.client);

  Future<CoachClientProgress?> getProgress(String relationshipId, String clientUserId) async {
    final raw = await client.rpc('stk_get_coach_pro_client_progress', params: {
      'p_relationship_id': relationshipId,
    });
    if (raw is! Map || raw['relationship_id'] != relationshipId ||
        raw['client_user_id'] != clientUserId || !raw.containsKey('snapshot')) {
      throw const FormatException('Invalid progress scope');
    }
    if (raw['snapshot'] == null) return null;
    if (raw['snapshot'] is! Map) throw const FormatException('Invalid progress snapshot');
    final row = Map<String, dynamic>.from(raw['snapshot'] as Map);
    bool integer(String key, int max) => row[key] is int &&
        (row[key] as int) >= 0 && (row[key] as int) <= max;
    bool numeric(String key, num max) => row[key] is num &&
        (row[key] as num).isFinite && (row[key] as num) >= 0 && (row[key] as num) <= max;
    final generatedAt = DateTime.tryParse('${row['generated_at']}');
    final lastWorkoutAt = row['last_workout_at'] == null ? null
        : DateTime.tryParse('${row['last_workout_at']}');
    if (!integer('workouts_7d', 1000) || !integer('workouts_30d', 4000) ||
        !integer('training_minutes_7d', 10080) || !integer('completed_working_sets_7d', 100000) ||
        !numeric('volume_7d', 1000000000000) || generatedAt == null ||
        (row['last_workout_at'] != null && lastWorkoutAt == null) ||
        (row['average_rir_7d'] != null && !numeric('average_rir_7d', 10))) {
      throw const FormatException('Invalid progress values');
    }
    if ((row['workouts_7d'] as int) > (row['workouts_30d'] as int)) {
      throw const FormatException('Invalid progress period counts');
    }
    return CoachClientProgress(clientUserId: clientUserId, workoutsVisible: false,
      workouts7d: row['workouts_7d'] as int, workouts30d: row['workouts_30d'] as int,
      trainingMinutes7d: row['training_minutes_7d'] as int,
      completedWorkingSets7d: row['completed_working_sets_7d'] as int,
      volume7d: (row['volume_7d'] as num).toDouble(),
      averageRir7d: (row['average_rir_7d'] as num?)?.toDouble(),
      lastWorkoutAt: lastWorkoutAt, generatedAt: generatedAt);
  }

  Future<CoachProSectionPage<CoachSharedWorkoutSummary>> listWorkouts(
      String relationshipId, String clientUserId, {int limit = 25, int offset = 0}) async {
    final raw = await client.rpc('stk_list_coach_pro_client_workouts', params: {
      'p_relationship_id': relationshipId, 'p_limit': limit, 'p_offset': offset,
    });
    if (raw is! Map || raw['relationship_id'] != relationshipId ||
        raw['client_user_id'] != clientUserId || raw['items'] is! List ||
        raw['total_count'] is! int || (raw['total_count'] as int) < 0) {
      throw const FormatException('Invalid workout page');
    }
    final items = <CoachSharedWorkoutSummary>[];
    for (final value in raw['items'] as List) {
      if (value is! Map) throw const FormatException('Invalid workout row');
      final row = Map<String, dynamic>.from(value);
      bool integer(String key, int max) => row[key] is int &&
          (row[key] as int) >= 0 && (row[key] as int) <= max;
      bool numeric(String key, num max) => row[key] is num &&
          (row[key] as num).isFinite && (row[key] as num) >= 0 && (row[key] as num) <= max;
      if (row['client_user_id'] != clientUserId || row['workout_id'] is! String ||
          (row['workout_id'] as String).isEmpty || (row['workout_id'] as String).runes.length > 120 ||
          DateTime.tryParse('${row['started_at']}') == null || row['routine_name'] is! String ||
          (row['routine_name'] as String).runes.length > 160 ||
          !integer('duration_seconds', 86400) || !integer('planned_working_sets', 2000) ||
          !integer('completed_working_sets', 2000) || !integer('completion_percent', 100) ||
          !numeric('volume', 1000000000000) ||
          (row['average_rir'] != null && !numeric('average_rir', 10))) {
        throw const FormatException('Invalid shared workout');
      }
      if ((row['completed_working_sets'] as int) > (row['planned_working_sets'] as int)) {
        throw const FormatException('Invalid set counts');
      }
      items.add(CoachSharedWorkoutSummary.fromJson(row));
    }
    if (items.length > limit || items.length > (raw['total_count'] as int)) {
      throw const FormatException('Invalid workout count');
    }
    return CoachProSectionPage(items: List.unmodifiable(items), totalCount: raw['total_count'] as int);
  }

  Future<CoachProClientSummary?> getSummary(String relationshipId) async {
    final result = await client.rpc('stk_get_coach_pro_client', params: {
      'p_relationship_id': relationshipId,
    });
    if (result is! List || result.isEmpty) return null;
    final row = CoachProClientSummary.fromJson(
      Map<String, dynamic>.from(result.single as Map),
    );
    if (row.relationshipId != relationshipId || row.clientUserId.isEmpty) {
      throw const FormatException('Invalid client summary');
    }
    return row;
  }

  Future<CoachProCheckinPage> listCheckins(String relationshipId,
      {int limit = 25, int offset = 0}) async {
    final result = await client.rpc('stk_list_coach_pro_client_checkins', params: {
      'p_relationship_id': relationshipId, 'p_limit': limit, 'p_offset': offset,
    });
    if (result is! List) throw const FormatException('Invalid check-in page');
    final items = <CoachCheckin>[];
    for (final raw in result) {
      final json = Map<String, dynamic>.from(raw as Map);
      if (DateTime.tryParse(json['created_at']?.toString() ?? '') == null ||
          json['energy'] is! num || json['recovery'] is! num) {
        throw const FormatException('Invalid check-in data');
      }
      final row = CoachCheckin.fromJson(json);
      if (row.relationshipId != relationshipId || row.id.isEmpty) {
        throw const FormatException('Invalid check-in relationship');
      }
      items.add(row);
    }
    return CoachProCheckinPage(
      items: List.unmodifiable(items),
      totalCount: result.isEmpty ? (offset == 0 ? 0 : null)
          : (result.first['total_count'] as num?)?.toInt(),
    );
  }
  Future<CoachProSectionPage<CoachProgramAssignmentSummary>> listPrograms(
      String relationshipId, {int limit = 25, int offset = 0}) =>
    _listSection('stk_list_coach_pro_client_programs', relationshipId, limit, offset,
      (json) {
        for (final key in ['starts_on', 'created_at', 'updated_at']) {
          if (DateTime.tryParse('${json[key]}') == null) {
            throw const FormatException('Invalid program date');
          }
        }
        if ('${json['name'] ?? ''}'.trim().isEmpty ||
            json['version'] is! num || json['duration_weeks'] is! num ||
            !AssignedProgramStatus.values.any((s) => s.name == json['status'])) {
          throw const FormatException('Invalid program summary');
        }
        return CoachProgramAssignmentSummary.fromJson(json);
      });

  Future<CoachProSectionPage<CoachProTaskSummary>> listTasks(
      String relationshipId, {int limit = 25, int offset = 0}) =>
    _listSection('stk_list_coach_pro_client_tasks', relationshipId, limit, offset,
      CoachProTaskSummary.fromJson);

  Future<CoachProSectionPage<T>> _listSection<T>(String rpc, String relationshipId,
      int limit, int offset, T Function(Map<String, dynamic>) parse) async {
    final result = await client.rpc(rpc, params: {
      'p_relationship_id': relationshipId, 'p_limit': limit, 'p_offset': offset,
    });
    if (result is! List) throw const FormatException('Invalid section page');
    final items = <T>[];
    for (final raw in result) {
      final json = Map<String, dynamic>.from(raw as Map);
      if (json['relationship_id'] != relationshipId ||
          '${json['id'] ?? ''}'.isEmpty) {
        throw const FormatException('Invalid section relationship');
      }
      items.add(parse(json));
    }
    return CoachProSectionPage(items: List.unmodifiable(items),
      totalCount: result.isEmpty ? (offset == 0 ? 0 : null)
          : (result.first['total_count'] as num?)?.toInt());
  }

}
