import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('root tabs have no duplicate heading but keep system safe area', () {
    final train = File('lib/features/routines/presentation/pages/routines_page.dart').readAsStringSync();
    final profile = File('lib/features/profile/presentation/pages/profile_page.dart').readAsStringSync();
    final progress = File('lib/features/progress/presentation/pages/progress_page.dart').readAsStringSync();
    final shell = File('lib/features/home/presentation/pages/home_screen.dart').readAsStringSync();
    expect(train, isNot(contains("title: Text('Entrenar'")));
    expect(train, contains('body: SafeArea('));
    expect(profile, isNot(contains("AppBar(title: Text('Perfil'")));
    expect(profile, contains('body: SafeArea('));
    expect(progress, isNot(contains("title: Text('Progreso'")));
    expect(progress, contains('toolbarHeight: 0'));
    for (final name in ['Resumen','Ejercicios','Músculos','Medidas']) {
      expect(progress, contains("Tab(text: '$name')"));
    }
    for (final name in ['Inicio','Entrenar','Progreso','Perfil']) {
      expect(shell, contains("label: '$name'"));
    }
    expect(shell, contains('IndexedStack('));
    expect(shell, contains('animateTo(0)'));
  });
}
