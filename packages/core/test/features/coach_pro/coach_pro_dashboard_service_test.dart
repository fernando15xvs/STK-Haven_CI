import 'dart:convert';

import 'package:core/features/coach_pro/data/coach_pro_dashboard_service.dart';
import 'package:core/features/coach_pro/domain/coach_pro_dashboard_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('sends the full typed query in one RPC and preserves redacted values', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.test', 'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode([{
          'relationship_id': 'relationship',
          'client_user_id': 'client',
          'relationship_status': 'active',
          'permissions': <String, bool>{},
          'workouts_7d': null,
          'active_task_count': null,
          'total_count': 31,
        }]), 200, request: request, headers: {'content-type': 'application/json'});
      }),
    );
    addTearDown(client.dispose);
    final service = CoachProDashboardService(client);
    final rows = await service.listClients(search: ' Ana ', limit: 25, offset: 25,
      status: CoachProClientStatusFilter.active, needsReview: true,
      sort: CoachProClientSort.recentWorkout);
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/rest/v1/rpc/stk_list_coach_pro_clients');
    expect(jsonDecode(requests.single.body), {
      'p_search': 'Ana', 'p_limit': 25, 'p_offset': 25,
      'p_status': 'active', 'p_needs_review': true, 'p_sort': 'recent_workout',
    });
    expect(rows.single.totalCount, 31);
    expect(rows.single.workouts7d, isNull);
    expect(rows.single.activeTaskCount, isNull);
    await service.listClients();
    expect(jsonDecode(requests.last.body), {
      'p_search': null, 'p_limit': 25, 'p_offset': 0,
      'p_status': 'all', 'p_needs_review': null, 'p_sort': 'review',
    });
  });
}
