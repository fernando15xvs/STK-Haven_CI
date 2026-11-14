/// Pure deadline adjustment: no timers or Hive side effects.
class RestTimerAdjustment {
  const RestTimerAdjustment._();

  /// Keeps sub-second precision and refuses expired or excessive rests.
  static DateTime? extend({
    required DateTime? endsAt,
    required DateTime now,
    required int additionalSeconds,
    int maxRemainingSeconds = 3600,
  }) {
    if (endsAt == null || !endsAt.isAfter(now) || additionalSeconds <= 0) {
      return null;
    }
    final updated = endsAt.add(Duration(seconds: additionalSeconds));
    final remaining = updated.difference(now).inMilliseconds;
    if (remaining <= 0 || remaining > maxRemainingSeconds * 1000) {
      return null;
    }
    return updated;
  }
}
