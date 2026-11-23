import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final file = File(
    'lib/features/routines/presentation/pages/create_routine_page.dart',
  );

  test('exercise setup has a real close/cancel, stable save and a scroll-only body', () {
    final code = file.readAsStringSync();
    expect(code, contains("ValueKey('exercise_config_close')"));
    expect(code, contains("ValueKey('exercise_config_cancel')"));
    expect(code, contains("ValueKey('exercise_config_save')"));
    expect(code, contains("ValueKey('exercise_config_scroll')"));
    expect(code, contains('return PopScope<void>('));
    expect(code, contains('Descartar cambios'));
    expect(code, contains('MediaQuery.viewInsetsOf(ctx).bottom'));
    expect(code, contains('LayoutBuilder('));
    expect(code, contains('SafeArea('));
  });

  test('shared visual tokens and progressive disclosure replace long cards', () {
    final code = file.readAsStringSync();
    expect(code, contains('return PremiumCard('));
    expect(code, contains('AppTypography.headlineSmall'));
    expect(code, contains('AppSpacing.md'));
    expect(code, contains('collapsible: true'));
    expect(code, contains("? 'Series y repeticiones'"));
    expect(code, contains("title: 'Preparación'"));
    expect(code, contains("title: 'Nota técnica'"));
    expect(code, contains("title: 'Trabajo unilateral'"));
  });

  test('unilateral has direct/paused options and optional second rest', () {
    final code = file.readAsStringSync();
    expect(code, contains('SegmentedButton<int>('));
    expect(code, contains("label: Text('Directo')"));
    expect(code, contains("label: Text('Con pausa')"));
    expect(code, contains('sideRestSeconds = 0;'));
    expect(code, contains('rememberedSideRest'));
    expect(code, contains('UnilateralRestChoices.forSelected(sideRestSeconds)'));
    expect(code, contains("label: 'Descanso entre series'"));
    expect(code, contains('min: 0,'));
    expect(code, contains('previousBilateralRest'));
    expect(code, contains("current?.restSeconds ?? 90"));
    expect(code, contains('unilateralSideRestSeconds: unilateral'));
  });
}
