import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachProDashboardService {
  final SupabaseClient client;

  const CoachProDashboardService(this.client);

  Future<List<CoachProClientSummary>> listClients({
    String search = '',
    int limit = 25,
    int offset = 0,
  }) async {
    final response = await client.rpc(
      'stk_list_coach_pro_clients',
      params: <String, dynamic>{
        'p_search': search.trim().isEmpty ? null : search.trim(),
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    if (response is! List) return const <CoachProClientSummary>[];

    return response
        .whereType<Map>()
        .map(
          (row) => CoachProClientSummary.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .where(
          (item) =>
              item.relationshipId.isNotEmpty &&
              item.clientUserId.isNotEmpty,
        )
        .toList(growable: false);
  }
}
