import 'package:core/domain/models/nutrition_guidance.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NutritionGuidanceService {
  final SupabaseClient client;

  const NutritionGuidanceService(this.client);

  Future<String> saveGuidance({
    required String clientUserId,
    String? planId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await client.rpc(
      'stk_save_nutrition_guidance',
      params: <String, dynamic>{
        'p_client_user_id': clientUserId,
        'p_plan_id': planId,
        'p_payload': payload,
      },
    );
    final id = response?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw const FormatException('Nutrition guidance id was empty.');
    }
    return id;
  }

  Future<List<NutritionGuidanceSummary>> listGuidance() async {
    final response = await client.rpc('stk_list_my_nutrition_guidance');
    if (response is! List) {
      return const <NutritionGuidanceSummary>[];
    }

    return response
        .whereType<Map>()
        .map(
          (row) => NutritionGuidanceSummary.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .where(
          (item) =>
              item.id.isNotEmpty &&
              item.coachUserId.isNotEmpty &&
              item.clientUserId.isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<NutritionGuidancePlan> getGuidance(
    String planId, {
    int? version,
  }) async {
    final response = await client.rpc(
      'stk_get_nutrition_guidance',
      params: <String, dynamic>{
        'p_plan_id': planId,
        'p_version': version,
      },
    );
    if (response is! Map) {
      throw const FormatException('Nutrition guidance payload was invalid.');
    }

    return NutritionGuidancePlan.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> archiveGuidance(String planId) async {
    await client.rpc(
      'stk_archive_nutrition_guidance',
      params: <String, dynamic>{'p_plan_id': planId},
    );
  }
}
