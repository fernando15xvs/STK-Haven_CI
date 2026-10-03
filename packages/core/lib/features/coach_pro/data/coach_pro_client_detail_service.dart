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
