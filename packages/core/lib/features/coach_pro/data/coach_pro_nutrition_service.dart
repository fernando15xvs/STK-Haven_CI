import 'package:core/domain/models/nutrition_guidance.dart';
import 'package:core/features/coach_pro/domain/coach_pro_task_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CoachProNutritionQuery = ({String relationshipId, String clientUserId, String planId, int version, int offset});
class CoachProNutritionPage {
  final NutritionGuidancePlan plan;
  final int totalCount;
  const CoachProNutritionPage(this.plan, this.totalCount);
}
class CoachProNutritionService {
  final SupabaseClient client;
  const CoachProNutritionService(this.client);
  Future<CoachProSectionPage<NutritionGuidanceSummary>> list(String relationshipId,
      String clientUserId, {int offset = 0}) async {
    final raw = await client.rpc('stk_list_coach_pro_nutrition', params: {
      'p_relationship_id': relationshipId, 'p_limit': 25, 'p_offset': offset,
    });
    if (raw is! Map || raw['relationship_id'] != relationshipId || raw['client_user_id'] != clientUserId ||
        raw['items'] is! List || !_count(raw['total_count'])) throw const FormatException('Invalid nutrition page');
    final items = <NutritionGuidanceSummary>[];
    for (final value in raw['items'] as List) {
      if (value is! Map) throw const FormatException('Invalid nutrition row');
      final row = Map<String, dynamic>.from(value);
      _scope(row, relationshipId, clientUserId);
      if (DateTime.tryParse('${row['updated_at']}') == null) throw const FormatException('Invalid nutrition date');
      items.add(NutritionGuidanceSummary.fromJson(row));
    }
    if (items.length > 25 || items.length > (raw['total_count'] as int)) throw const FormatException('Invalid count');
    return CoachProSectionPage(items: List.unmodifiable(items), totalCount: raw['total_count'] as int);
  }
  Future<CoachProNutritionPage> load(CoachProNutritionQuery query) async {
    final raw = await client.rpc('stk_get_coach_pro_nutrition_page', params: {
      'p_relationship_id': query.relationshipId, 'p_plan_id': query.planId,
      'p_version': query.version, 'p_offset': query.offset,
    });
    if (raw is! Map || raw['plan'] is! Map || !_count(raw['total_count']) || (raw['total_count'] as int) > 20) {
      throw const FormatException('Invalid nutrition detail');
    }
    final row = Map<String, dynamic>.from(raw['plan'] as Map);
    _scope(row, query.relationshipId, query.clientUserId);
    if (row['id'] != query.planId || row['version'] != query.version ||
        DateTime.tryParse('${row['created_at']}') == null || row['meals'] is! List ||
        !_text(row['overview'], 4000) || !_text(row['hydration_notes'], 2000) ||
        !_text(row['general_notes'], 6000) || !_text(row['scope_notice'], 1000, min: 20)) {
      throw const FormatException('Invalid nutrition version');
    }
    final meals = row['meals'] as List;
    if (meals.length > 5 || meals.length > (raw['total_count'] as int)) throw const FormatException('Invalid meals count');
    for (final meal in meals) {
      if (meal is! Map || !_text(meal['id'], 100, min: 1) || !_position(meal['position'], 20) ||
          !_text(meal['name'], 100, min: 1) || !_text(meal['timing_label'], 80) ||
          !_text(meal['notes'], 2000) || meal['items'] is! List || (meal['items'] as List).length > 50) {
        throw const FormatException('Invalid shared meal');
      }
      for (final item in meal['items'] as List) {
        if (item is! Map || !_text(item['id'], 100, min: 1) || !_position(item['position'], 50) ||
            !_text(item['food_example'], 160, min: 1) || !_text(item['serving_note'], 500)) {
          throw const FormatException('Invalid food example');
        }
      }
    }
    return CoachProNutritionPage(NutritionGuidancePlan.fromJson(row), raw['total_count'] as int);
  }
}
bool _count(dynamic v) => v is int && v >= 0;
bool _position(dynamic v, int max) => v is int && v >= 0 && v < max;
bool _text(dynamic v, int max, {int min = 0}) => v is String && v.trim().runes.length >= min && v.runes.length <= max;
void _scope(Map<String, dynamic> row, String relationshipId, String clientUserId) {
  if (row['relationship_id'] != relationshipId || row['client_user_id'] != clientUserId ||
      !_text(row['id'], 100, min: 1) || !_text(row['coach_user_id'], 100, min: 1) ||
      !_text(row['title'], 120, min: 1) || row['current_version'] is! int ||
      (row['current_version'] as int) < 1 || (row['current_version'] as int) > 10000 ||
      !NutritionGuidanceStatus.values.any((s) => s.name == row['status'])) {
    throw const FormatException('Invalid nutrition scope');
  }
}
