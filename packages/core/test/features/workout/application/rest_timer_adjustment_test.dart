import 'package:flutter_test/flutter_test.dart';
import 'package:core/features/workout/application/rest_timer_adjustment.dart';

void main() {
  final now = DateTime.utc(2026, 11, 14, 18, 0, 0);

  test('adds exactly 15 or 30 seconds without rounding the deadline', () {
    final initial = now.add(const Duration(seconds: 90, milliseconds: 375));
    final plus15 = RestTimerAdjustment.extend(
      endsAt: initial, now: now, additionalSeconds: 15,
    );
    expect(plus15, initial.add(const Duration(seconds: 15)));
    expect(RestTimerAdjustment.extend(
      endsAt: plus15, now: now, additionalSeconds: 30,
    ), initial.add(const Duration(seconds: 45)));
  });

  test('custom seconds allow non-multiples of 15', () {
    final end = now.add(const Duration(seconds: 33));
    expect(RestTimerAdjustment.extend(
      endsAt: end, now: now, additionalSeconds: 7,
    ), now.add(const Duration(seconds: 40)));
  });

  test('extension and old-deadline expiry are independent', () {
    // Models the OS countdown: an old 60s alarm must not represent a
    // newly extended rest that now ends at 90s.
    final initial = now.add(const Duration(seconds: 60));
    final extended = RestTimerAdjustment.extend(
      endsAt: initial,
      now: now.add(const Duration(seconds: 45)),
      additionalSeconds: 30,
    );
    expect(extended, now.add(const Duration(seconds: 90)));
    expect(extended!.isAfter(initial), isTrue);
    expect(extended.isAfter(now.add(const Duration(seconds: 60))), isTrue);
    expect(RestTimerAdjustment.extend(
      endsAt: initial,
      now: initial,
      additionalSeconds: 15,
    ), isNull,
        reason: 'An already expired notification must not resurrect.');
    expect(RestTimerAdjustment.extend(
      endsAt: initial,
      now: now.add(const Duration(seconds: 61)),
      additionalSeconds: 15,
    ), isNull);
  });

  test('rejects expired, missing, zero or excessive countdowns', () {
    expect(RestTimerAdjustment.extend(
      endsAt: null, now: now, additionalSeconds: 15,
    ), isNull);
    expect(RestTimerAdjustment.extend(
      endsAt: now, now: now, additionalSeconds: 15,
    ), isNull);
    expect(RestTimerAdjustment.extend(
      endsAt: now.add(const Duration(seconds: 60)),
      now: now, additionalSeconds: 0,
    ), isNull);
    expect(RestTimerAdjustment.extend(
      endsAt: now.add(const Duration(minutes: 59)),
      now: now, additionalSeconds: 120,
    ), isNull);
  });
}
