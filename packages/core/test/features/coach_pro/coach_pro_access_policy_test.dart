import 'package:core/domain/models/subscription_entitlement.dart';
import 'package:core/features/coach_pro/application/coach_pro_access_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SubscriptionEntitlement entitlement({
    bool accessActive = true,
    int clientLimit = 5,
    int activeClientCount = 0,
    SubscriptionEntitlementStatus status =
        SubscriptionEntitlementStatus.active,
  }) {
    return SubscriptionEntitlement(
      product: SubscriptionProduct.coachPro,
      status: status,
      tier: 'test',
      clientLimit: clientLimit,
      activeClientCount: activeClientCount,
      accessActive: accessActive,
      fetchedAt: DateTime.utc(2026, 9, 30),
    );
  }

  test('missing entitlement never unlocks professional tools', () {
    expect(
      CoachProAccessPolicy.professionalTools(null),
      CoachProAccessReason.missingEntitlement,
    );
  });

  test('status text cannot override server-authored access flag', () {
    final forgedLooking = entitlement(
      status: SubscriptionEntitlementStatus.active,
      accessActive: false,
    );

    expect(forgedLooking.canUseCoachPro, isFalse);
    expect(
      CoachProAccessPolicy.professionalTools(forgedLooking),
      CoachProAccessReason.inactiveEntitlement,
    );
  });

  test('active server entitlement enables professional tools', () {
    expect(
      CoachProAccessPolicy.professionalTools(entitlement()),
      CoachProAccessReason.allowed,
    );
  });

  test('client limit blocks only new-client action', () {
    final full = entitlement(clientLimit: 3, activeClientCount: 3);

    expect(
      CoachProAccessPolicy.professionalTools(full),
      CoachProAccessReason.allowed,
    );
    expect(
      CoachProAccessPolicy.addClient(full),
      CoachProAccessReason.clientLimitReached,
    );
    expect(full.remainingClientSlots, 0);
  });

  test('remaining client slots never becomes negative', () {
    final overLimit = entitlement(clientLimit: 2, activeClientCount: 4);
    expect(overLimit.remainingClientSlots, 0);
  });

  test('wire parser rejects unknown product or status', () {
    expect(
      () => SubscriptionEntitlement.fromJson(<String, dynamic>{
        'product': 'unknown',
        'status': 'active',
        'access_active': true,
      }),
      throwsFormatException,
    );
  });
}
