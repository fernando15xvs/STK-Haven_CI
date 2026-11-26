import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('adaptation exposes explicit and reversible actions',(){
    final sheet=File('lib/features/programs/presentation/widgets/adaptive_planning_sheet.dart').readAsStringSync();
    for(final label in ['No puedo entrenar hoy','Tengo menos días disponibles','Cambiar mi próximo entrenamiento',
      'Lesión o molestia física','Reparar orden de rotación','Si no entreno más esta semana','Planificación cerrada']){
      expect(sheet,contains(label));
    }
    expect(sheet,contains('ProgramAdaptationPolicy.setUnavailableDays'));
    expect(sheet,contains('ProgramAdaptationPolicy.repairRolling'));
    expect(sheet,contains('ProgramAdaptationPolicy.exchange'));
  });
}
