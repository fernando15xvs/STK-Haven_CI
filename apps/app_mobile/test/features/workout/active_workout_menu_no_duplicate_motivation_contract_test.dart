import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active workout overflow menu keeps tools, not duplicate Motivation', () {
    final source = File(
      'lib/features/workout/presentation/active_workout_page_content.dart',
    ).readAsStringSync();
    final start = source.indexOf("tooltip: 'Opciones del entrenamiento'");
    final end = source.indexOf('body: Column(', start);

    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final menu = source.substring(start, end);
    expect(menu, contains("value: 'supersets'"));
    expect(menu, contains("value: 'plates'"));
    expect(menu, contains("value: 'discard'"));
    expect(menu, isNot(contains("value: 'motivation'")));
    expect(menu, isNot(contains("title: Text('STK Motivation')")));
    expect(menu, isNot(contains("case 'motivation':")));
    expect(source, contains("label: 'Finalizar entrenamiento'"));
  });

  test('Motivation remains accessible from plus and playing mini-player', () {
    final home = File(
      'lib/features/home/presentation/pages/home_screen.dart',
    ).readAsStringSync();
    final workout = File(
      'lib/features/workout/presentation/active_workout_page_content.dart',
    ).readAsStringSync();

    expect(home, contains("label: 'Motivation'"));
    expect(home, contains('onTap: () => _openPage(const MotivationPage())'));
    expect(workout, contains(
      'const MotivationMiniPlayer(showLauncherWhenEmpty: false)',
    ));
    expect(workout, isNot(contains(
      "import 'package:gym_tracker/features/motivation/presentation/"
      "motivation_page.dart';",
    )));
  });
}
