import 'package:core/core/services/supabase_client_gateway.dart';
import 'package:core/domain/models/subscription_entitlement.dart';
import 'package:core/features/coach_pro/data/coach_pro_entitlement_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';

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
    final identity = ref.watch(appIdentityProvider.select((value) => (value.signedIn, value.userId)));
    if (!identity.$1 || identity.$2 == null) return null;
    return _load();
  }

  Future<void> refresh() async {
    // Rebuild using the current identity; Riverpod discards previous build results.
    ref.invalidateSelf();
    await future;
  }

  Future<SubscriptionEntitlement?> _load() {
    return ref.read(coachProEntitlementServiceProvider).getOwnEntitlement();
  }
}
