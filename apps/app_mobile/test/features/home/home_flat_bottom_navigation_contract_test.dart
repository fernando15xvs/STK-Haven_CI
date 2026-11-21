import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/home/presentation/pages/home_screen.dart',
  ).readAsStringSync();

  test('bottom tabs have no card, border or shadow surface', () {
    expect(source, contains("ValueKey('flat_bottom_navigation')"));
    expect(source, isNot(contains('class _BottomBarSurface')));
    expect(source, isNot(contains('_BottomBarSurface(')));

    final dockStart = source.indexOf('bottomNavigationBar: SafeArea(');
    final dockEnd = source.indexOf('class _BottomNavItem', dockStart);
    expect(dockStart, greaterThan(0));
    expect(dockEnd, greaterThan(dockStart));
    final dock = source.substring(dockStart, dockEnd);

    expect(dock, contains('top: false,'));
    expect(dock, contains('const MotivationHomeMiniPlayer()'));
    expect(dock, contains('const EdgeInsets.symmetric(horizontal: 14)'));
    expect(dock, isNot(contains('BoxDecoration(')));
    expect(dock, isNot(contains('BoxShadow(')));
    expect(dock, isNot(contains('Border.all(')));
    expect(dock, isNot(contains('ClipRRect(')));
  });

  test('icons sit lower while the iPhone home safe area stays protected', () {
    expect(source, contains('bottomNavigationBar: SafeArea('));
    expect(source, contains('padding: const EdgeInsets.only(top: 10, bottom: 2)'));
    expect(source, isNot(contains('bottom: 4),\n          child: _BottomBarSurface(')));
    expect(source, contains('Semantics('));
    expect(source, contains('selected: isSelected'));
    expect(source, contains('label: label'));
    expect(source, contains('maxLines: 2'));
  });

  test('the plus menu and all four tab destinations are unchanged', () {
    for (final tab in const ['Inicio', 'Entrenar', 'Progreso', 'Perfil']) {
      expect(source, contains("label: '$tab'"));
    }
    for (final tabIndex in [0, 1, 2, 3]) {
      expect(source, contains('onTap: () => _selectTab($tabIndex)'));
    }
    expect(source, contains('_FloatingMenuButton('));
    expect(source, contains('faithEnabled: faithEnabled'));
    expect(source, contains('coachEnabled: coachEnabled'));
    expect(source, contains("label: _isOpen ? 'Cerrar accesos rápidos'"));
    expect(source, contains('width: 48,'));
    expect(source, contains('height: 48,'));
    expect(source, contains('IndexedStack('));
  });
}
