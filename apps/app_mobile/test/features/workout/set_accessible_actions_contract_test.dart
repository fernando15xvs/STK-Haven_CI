import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every working set exposes an accessible menu including delete', () {
    final source = File(
      'lib/features/workout/presentation/active_workout_page_content.dart',
    ).readAsStringSync();
    expect(source, contains("tooltip: 'Acciones de la serie'"));
    expect(source, contains("value: 'delete'"));
    expect(source, contains("child: Text('Eliminar serie')"));
    expect(source, contains('Future<void> _confirmRemoveSet()'));
    expect(source, contains('onLongPress: _confirmRemoveSet'));
    expect(source, contains('live.exercises[widget.exIndex].instanceId'));
  });
}
