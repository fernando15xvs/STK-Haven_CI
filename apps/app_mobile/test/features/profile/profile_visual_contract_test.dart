import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Profile groups settings with one owner and no training dashboards', () {
    final screen = File(
      'lib/features/profile/presentation/pages/profile_page.dart',
    ).readAsStringSync();
    final identity = File(
      '../../packages/core/lib/features/profile/presentation/widgets/personal_profile_summary.dart',
    ).readAsStringSync();
    expect(screen, contains("SectionHeading(title: 'PREFERENCIAS')"));
    expect(screen, contains("SectionHeading(title: 'SERVICIOS Y PRIVACIDAD')"));
    expect(screen, contains("SectionHeading(title: 'RECONOCIMIENTOS')"));
    expect(screen, contains('PremiumCard('));
    expect(screen, isNot(contains('STK MOTIVATION')));
    expect(screen, isNot(contains('PROGRAMA ACTUAL')));
    expect(identity, isNot(contains('Sesiones realizadas')));
    expect(identity, isNot(contains('Récords personales')));
  });

  test('profile editors protect unsaved changes', () {
    final personal = File(
      '../../packages/core/lib/features/profile/presentation/pages/personal_profile_page.dart',
    ).readAsStringSync();
    final experience = File(
      '../../packages/core/lib/features/profile/presentation/pages/experience_preferences_page.dart',
    ).readAsStringSync();
    for (final editor in [personal, experience]) {
      expect(editor, contains('PopScope('));
      expect(editor, contains('_hasUnsavedChanges'));
      expect(editor, contains('Descartar cambios'));
    }
    expect(personal, isNot(contains("Text('Mi entrenamiento'")));
    expect(experience, isNot(contains('setWeightUnit(draft.weightUnit)')));
  });

  test('Achievements use semantic theme colors and flexible list layout', () {
    final badges = File(
      'lib/features/profile/presentation/pages/achievements_page.dart',
    ).readAsStringSync();
    expect(badges, contains('SliverList.builder('));
    expect(badges, isNot(contains('SliverGrid(')));
    expect(badges, isNot(contains('Colors.grey')));
    expect(badges, isNot(contains('Colors.amber')));
    expect(badges, contains('colors.gold'));
  });
}
