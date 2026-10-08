import 'package:core/features/coach_pro/domain/coach_pro_checkin_cadence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachProCheckinCadenceService {
  final SupabaseClient client;
  const CoachProCheckinCadenceService(this.client);

  Future<CoachProCheckinCadence?> get(String relationshipId) async {
    final response = await client.rpc('stk_get_coach_pro_checkin_cadence',
      params: {'p_relationship_id': relationshipId});
    if (response == null) return null;
    if (response is! Map) {
      throw const FormatException('Invalid check-in cadence payload');
    }
    return CoachProCheckinCadence.fromJson(
      Map<String, dynamic>.from(response),
      expectedRelationshipId: relationshipId,
    );
  }

  Future<int> propose({
    required String relationshipId,
    required Set<int> weekdays,
    required int? expectedRevision,
  }) async {
    if (weekdays.isEmpty || weekdays.length > 3 ||
        weekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError.value(weekdays, 'weekdays', 'Choose 1 to 3 weekdays');
    }
    final sorted = weekdays.toList()..sort();
    final response = await client.rpc('stk_propose_coach_pro_checkin_cadence',
      params: {
        'p_relationship_id': relationshipId,
        'p_weekdays': sorted,
        'p_expected_revision': expectedRevision,
      });
    if (response is! int || response < 1 || response > 10000) {
      throw const FormatException('Invalid check-in proposal revision');
    }
    return response;
  }

  Future<int> respond({
    required String relationshipId,
    required int expectedRevision,
    required bool accept,
  }) async {
    if (expectedRevision < 1 || expectedRevision > 10000) {
      throw ArgumentError.value(expectedRevision, 'expectedRevision');
    }
    final response = await client.rpc('stk_respond_coach_pro_checkin_cadence',
      params: {
        'p_relationship_id': relationshipId,
        'p_expected_revision': expectedRevision,
        'p_accept': accept,
      });
    if (response is! int || response <= expectedRevision ||
        response > 10000) {
      throw const FormatException('Invalid check-in decision revision');
    }
    return response;
  }
}
