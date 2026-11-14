import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Inicio keeps daily message immediately after recovery and opt-in',
      () {
    final source = File(
      'lib/features/home/presentation/pages/dashboard_page.dart',
    ).readAsStringSync();
    final recovery = source.indexOf('const RecoveryCheckInCard(compact: true)');
    final message = source.indexOf('const _DailyMessageCard(),');
    final wellness = source.indexOf("'BIENESTAR'");
    final activity = source.indexOf("'ACTIVIDAD'");
    expect(recovery, greaterThanOrEqualTo(0));
    expect(message, greaterThan(recovery));
    expect(wellness, greaterThan(message));
    expect(activity, greaterThan(wellness));
    expect(source, contains('faithEnabled && settings.showDailyVerse'));
    expect(source, isNot(contains('class _ActiveProgramCard')));
    expect(source, contains('maxLines: 3,'));
    expect(source, contains('TextOverflow.ellipsis'));
    expect(source, contains("const Text('Leer completo')"));
    expect(source, contains('loadingCard(providerError: true)'));
    expect(source, isNot(contains('ContextualPassageDetails(')));
  });
}
