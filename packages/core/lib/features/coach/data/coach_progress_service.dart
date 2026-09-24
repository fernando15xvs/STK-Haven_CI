import 'package:core/domain/models/coach_client_progress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachProgressService {
  final SupabaseClient client;

  const CoachProgressService(this.client);

  Future<void> syncOwnProgress(CoachClientProgress progress) async {
    await client.rpc(
      'stk_sync_own_progress',
      params: <String, dynamic>{
        'p_progress': progress.snapshotToJson(),
        'p_recent_workouts': progress.recentWorkoutsToJson(),
      },
    );
  }

  Future<CoachClientProgress> getClientProgress(String clientUserId) async {
    final response = await client.rpc(
      'stk_get_client_progress',
      params: <String, dynamic>{
        'p_client_user_id': clientUserId,
      },
    );
    if (response is! Map) {
      throw const FormatException('Client progress payload was invalid.');
    }
    return CoachClientProgress.fromRpcJson(
      Map<String, dynamic>.from(response),
    );
  }
}
