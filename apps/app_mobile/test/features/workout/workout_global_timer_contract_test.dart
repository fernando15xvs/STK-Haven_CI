import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global workout clock emits immediately from the stable session identity', () {
    final provider = File('../../packages/core/lib/features/workout/application/active_workout_provider.dart').readAsStringSync();
    expect(provider, contains('session.id, session.startedAt'));
    expect(provider, contains('yield elapsed();'));
    expect(provider, contains('yield* Stream.periodic('));
    final ui = File('lib/features/workout/presentation/active_workout_page_content.dart').readAsStringSync();
    expect(ui, contains('.difference(session.startedAt)'));
    expect(ui, contains('.clamp(0, 1 << 30)'));
  });
}
