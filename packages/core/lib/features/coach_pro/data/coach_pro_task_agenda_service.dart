import 'package:core/features/coach_pro/domain/coach_pro_task_agenda.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachProTaskAgendaService {
  final SupabaseClient client;
  const CoachProTaskAgendaService(this.client);

  Future<CoachProAgendaPage> list({
    required String relationshipId,
    int offset = 0,
  }) async {
    if (relationshipId.isEmpty) throw ArgumentError.value(relationshipId);
    if (offset < 0 || offset > 10000 || offset % 25 != 0) {
      throw ArgumentError.value(offset, 'offset');
    }
    final raw = await client.rpc('stk_list_coach_pro_task_schedule', params: {
      'p_relationship_id': relationshipId,
      'p_days': 14,
      'p_limit': 25,
      'p_offset': offset,
    });
    if (raw is! Map) throw const FormatException('Invalid task agenda');
    return CoachProAgendaPage.fromJson(
      Map<String, dynamic>.from(raw),
      expectedRelationshipId: relationshipId,
    );
  }
}
