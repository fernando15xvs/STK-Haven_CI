import 'package:core/features/coach_pro/domain/coach_pro_dashboard_query.dart';
import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/domain/models/coach_pro_portfolio_overview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachProDashboardService {
  final SupabaseClient client;

  const CoachProDashboardService(this.client);

  /// Totals cover every authorized relationship, not just one roster page.
  Future<CoachProPortfolioOverview> getPortfolioOverview() async {
    final response = await client.rpc('stk_get_coach_pro_portfolio_overview');
    if (response is! Map) {
      throw const FormatException('Invalid Coach Pro portfolio response');
    }
    return CoachProPortfolioOverview.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<List<CoachProClientSummary>> listClients({
    String search = '',
    int limit = 25,
    int offset = 0,
    CoachProClientStatusFilter status = CoachProClientStatusFilter.all,
    bool? needsReview,
    CoachProClientSort sort = CoachProClientSort.review,
  }) async {
    final response = await client.rpc(
      'stk_list_coach_pro_clients',
      params: <String, dynamic>{
        'p_search': search.trim().isEmpty ? null : search.trim(),
        'p_limit': limit,
        'p_offset': offset,
        'p_status': status.name,
        'p_needs_review': needsReview,
        'p_sort': sort.wireValue,
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
