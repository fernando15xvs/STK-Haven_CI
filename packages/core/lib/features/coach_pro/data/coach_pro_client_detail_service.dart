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
}
