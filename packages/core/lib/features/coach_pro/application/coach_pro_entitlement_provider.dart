import 'package:core/domain/models/subscription_entitlement.dart';
import 'package:core/features/coach_pro/data/coach_pro_entitlement_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final coachProEntitlementServiceProvider =
    Provider<CoachProEntitlementService>((ref) {
  return CoachProEntitlementService(Supabase.instance.client);
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
