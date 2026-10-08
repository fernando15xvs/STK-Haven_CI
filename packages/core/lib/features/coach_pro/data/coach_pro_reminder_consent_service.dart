import 'package:core/features/coach_pro/domain/coach_pro_reminder_consent.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachProReminderConsentService {
  final SupabaseClient client;
  const CoachProReminderConsentService(this.client);

  Future<CoachProReminderConsent> get(String relationshipId) async {
    final result = await client.rpc('stk_get_coach_pro_reminder_opt_in',
      params: {'p_relationship_id': relationshipId});
    if (result is! Map) throw const FormatException('Invalid reminder consent');
    return CoachProReminderConsent.fromJson(
      Map<String, dynamic>.from(result),
    );
  }

  Future<void> set({
    required String relationshipId,
    required bool enabled,
    required int hourLocal,
    required int? expectedCadenceRevision,
  }) async {
    if (hourLocal < 7 || hourLocal > 22 ||
        (enabled && (expectedCadenceRevision == null ||
                     expectedCadenceRevision < 1))) {
      throw ArgumentError('Invalid reminder preference');
    }
    final response = await client.rpc('stk_set_coach_pro_reminder_opt_in',
      params: {
        'p_relationship_id': relationshipId,
        'p_enabled': enabled,
        'p_hour_local': hourLocal,
        'p_expected_cadence_revision': expectedCadenceRevision,
      });
    if (response != enabled) {
      throw const FormatException('Unexpected reminder opt-in response');
    }
  }
}
