import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/progress/presentation/widgets/body_measurement_silhouette.dart';

void main() {
  test('deterministic label packing never overlaps on the same side', () {
    for (final width in [320.0, 390.0, 430.0]) {
      for (final fontScale in [1.0, 1.6, 2.0]) {
        final labelHeight = 48.0 * fontScale;
        final canvasHeight = [
          405.0, width * 1.43, labelHeight * 4 + 40,
        ].reduce((a, b) => a > b ? a : b);
        final top = resolveMeasurementCalloutTops(
          desiredRows: const [.085, .160, .265, .410, .405, .720, .720],
          onLeft: const [true, false, true, true, false, true, false],
          canvasHeight: canvasHeight,
          badgeHeight: labelHeight,
        );
        expect(top, hasLength(7));
        for (final side in [true, false]) {
          const sides = [true, false, true, true, false, true, false];
        final sideTops = [
          for (var i = 0; i < top.length; i++)
            if (sides[i] == side) top[i],
        ]..sort();
          for (var j = 0; j < sideTops.length; j++) {
            expect(sideTops[j], greaterThanOrEqualTo(3.99));
            expect(sideTops[j] + labelHeight,
                lessThanOrEqualTo(canvasHeight - 3.99));
            if (j > 0) {
              expect(sideTops[j] - sideTops[j - 1],
                  greaterThanOrEqualTo(labelHeight + 7.99));
            }
          }
        }
      }
    }
  });

  test('unrecorded contours do not create phantom positioning', () {
    final empty = resolveMeasurementCalloutTops(
      desiredRows: const [], onLeft: const [],
      canvasHeight: 405, badgeHeight: 60,
    );
    expect(empty, isEmpty);
    final onlyOne = resolveMeasurementCalloutTops(
      desiredRows: const [.72], onLeft: const [false],
      canvasHeight: 405, badgeHeight: 60,
    );
    expect(onlyOne.single, closeTo(.72 * 405, .001));
  });

  test('same-side collisions are pushed apart without crossing sides', () {
    final tops = resolveMeasurementCalloutTops(
      desiredRows: const [.25, .26, .27, .60],
      onLeft: const [true, true, true, false],
      canvasHeight: 420, badgeHeight: 70,
    );
    expect(tops[1] - tops[0], greaterThanOrEqualTo(78));
    expect(tops[2] - tops[1], greaterThanOrEqualTo(78));
    expect(tops[3], closeTo(.60 * 420, .001));
  });
}
