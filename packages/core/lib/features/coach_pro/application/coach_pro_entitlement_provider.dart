import 'package:core/core/services/supabase_client_gateway.dart';
import 'package:core/domain/models/subscription_entitlement.dart';
import 'package:core/features/coach_pro/data/coach_pro_entitlement_service.dart';
import 'package:riverpod/riverpod.dart';

final coachProEntitlementServiceProvider =
    Provider<CoachProEntitlementService>((ref) {
  return CoachProEntitlementService(CoreSupabaseClient.client);
});

final coachProEntitlementProvider = AsyncNotifierProvider<
    CoachProEntitlementNotifier,
    SubscriptionEntitlement?>(CoachProEntitlementNotifier.new);

class CoachProEntitlementNotifier
    extends AsyncNotifier<SubscriptionEntitlement?> {
  @override
  Future<SubscriptionEntitlement?> build() async {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<SubscriptionEntitlement?> _load() {
    return ref.read(coachProEntitlementServiceProvider).getOwnEntitlement();
  }
}
