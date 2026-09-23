import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/shared/app/stk_haven_app.dart';

void main() {
  test('MyApp remains a valid shared Flutter root widget', () {
    const app = MyApp();
    expect(app, isA<Widget>());
  });
}
