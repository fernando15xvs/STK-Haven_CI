import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('steps card communicates age and provenance without changing the total',(){
    final widget=File(
      'lib/features/home/presentation/widgets/daily_steps_widget.dart',
    ).readAsStringSync();
    expect(widget,contains('StepsReadingFreshnessPolicy.resolve('));
    expect(widget,contains("ValueKey('home_steps_reading_provenance')"));
    expect(widget,contains("'Lectura antigua'"));
    expect(widget,contains("'Dispositivo · hora desconocida'"));
    expect(widget,contains("'Desde el dispositivo'"));
    expect(widget,contains("'Sin sincronizar'"));
    expect(widget,contains('Última lectura del dispositivo:'));
    expect(widget,contains('La lectura puede no reflejar los pasos actuales.'));
    expect(widget,contains('ref.watch(dailyStepsProvider)'));
    expect(widget,contains('format.format(state.steps)'));
  });
}
