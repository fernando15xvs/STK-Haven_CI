import 'package:core/domain/models/subscription_entitlement.dart';

enum CoachProAccessReason {
  allowed,
  missingEntitlement,
  inactiveEntitlement,
  clientLimitReached,
}

/// Client-side UX policy only.
///
/// The backend remains authoritative. This policy may hide/disable controls for
/// a better experience, but every professional mutation must still be rejected
/// server-side when the entitlement is invalid.
class CoachProAccessPolicy {
  const CoachProAccessPolicy._();

  static CoachProAccessReason professionalTools(
    SubscriptionEntitlement? entitlement,
  ) {
    if (entitlement == null) {
      return CoachProAccessReason.missingEntitlement;
    }
    if (!entitlement.accessActive) {
      return CoachProAccessReason.inactiveEntitlement;
    }
    return CoachProAccessReason.allowed;
  }

  static CoachProAccessReason addClient(
    SubscriptionEntitlement? entitlement,
  ) {
    final base = professionalTools(entitlement);
    if (base != CoachProAccessReason.allowed) return base;
    if (!entitlement!.canAddClient) {
      return CoachProAccessReason.clientLimitReached;
    }
    return CoachProAccessReason.allowed;
  }
}
