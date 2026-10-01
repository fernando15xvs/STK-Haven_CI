enum SubscriptionProduct {
  coachPro('coach_pro');

  final String wireName;
  const SubscriptionProduct(this.wireName);

  static SubscriptionProduct? fromWireName(String? value) {
    for (final product in values) {
      if (product.wireName == value) return product;
    }
    return null;
  }
}

enum SubscriptionEntitlementStatus {
  trial('trial'),
  active('active'),
  grace('grace'),
  pastDue('past_due'),
  canceled('canceled'),
  expired('expired');

  final String wireName;
  const SubscriptionEntitlementStatus(this.wireName);

  static SubscriptionEntitlementStatus? fromWireName(String? value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// Read-only snapshot returned by the STK Haven backend.
///
/// [accessActive] is intentionally server-authored. The Flutter client may cache
/// this model to render offline UX, but it must never use locally persisted or
/// user-editable state as authority for Coach Pro operations.
class SubscriptionEntitlement {
  final SubscriptionProduct product;
  final SubscriptionEntitlementStatus status;
  final String tier;
  final int clientLimit;
  final int activeClientCount;
  final DateTime? startsAt;
  final DateTime? currentPeriodEnd;
  final DateTime? graceUntil;
  final bool accessActive;
  final DateTime fetchedAt;

  const SubscriptionEntitlement({
    required this.product,
    required this.status,
    required this.tier,
    required this.clientLimit,
    required this.activeClientCount,
    required this.accessActive,
    required this.fetchedAt,
    this.startsAt,
    this.currentPeriodEnd,
    this.graceUntil,
  });

  bool get canUseCoachPro => accessActive;

  bool get canAddClient =>
      accessActive && activeClientCount < clientLimit;

  int get remainingClientSlots {
    final remaining = clientLimit - activeClientCount;
    return remaining < 0 ? 0 : remaining;
  }

  factory SubscriptionEntitlement.fromJson(Map<String, dynamic> json) {
    final product = SubscriptionProduct.fromWireName(
      json['product']?.toString(),
    );
    final status = SubscriptionEntitlementStatus.fromWireName(
      json['status']?.toString(),
    );
    if (product == null || status == null) {
      throw const FormatException('Unsupported subscription entitlement.');
    }

    final rawLimit = (json['client_limit'] as num?)?.toInt() ?? 0;
    final rawActive = (json['active_client_count'] as num?)?.toInt() ?? 0;

    return SubscriptionEntitlement(
      product: product,
      status: status,
      tier: json['tier']?.toString() ?? '',
      clientLimit: rawLimit < 0 ? 0 : rawLimit,
      activeClientCount: rawActive < 0 ? 0 : rawActive,
      startsAt: _date(json['starts_at']),
      currentPeriodEnd: _date(json['current_period_end']),
      graceUntil: _date(json['grace_until']),
      accessActive: json['access_active'] as bool? ?? false,
      fetchedAt: DateTime.now(),
    );
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
