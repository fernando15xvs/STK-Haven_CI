import 'package:core/features/progress/application/progress_metrics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no previous volume or workout count means no valid growth rate', () {
    expect(periodPercentChange(149801, 0), isNull);
    expect(periodPercentChange(0, 0), isNull);
    expect(periodPercentChange(3, 0), isNull);
    expect(periodPercentChange(double.nan, 10), isNull);
    expect(periodPercentChange(10, double.infinity), isNull);
  });

  test('zero current with positive previous is a real 100% decrease', () {
    expect(periodPercentChange(0, 100), -100);
  });

  test('positive baseline produces accurate increases/decreases', () {
    expect(periodPercentChange(122.8, 100), closeTo(22.8, 0.0001));
    expect(periodPercentChange(75, 100), -25);
  });
}
