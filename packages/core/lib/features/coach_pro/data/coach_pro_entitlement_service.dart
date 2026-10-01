import 'package:core/domain/models/subscription_entitlement.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachProEntitlementService {
  final SupabaseClient client;

  const CoachProEntitlementService(this.client);

  Future<SubscriptionEntitlement?> getOwnEntitlement() async {
    final response = await client.rpc(
      'stk_get_own_subscription_entitlement',
      params: <String, dynamic>{
        'p_product': SubscriptionProduct.coachPro.wireName,
      },
    );
    if (response is! Map) return null;

    final payload = Map<String, dynamic>.from(response);
    if (payload['exists'] != true) return null;
    return SubscriptionEntitlement.fromJson(payload);
  }
}
