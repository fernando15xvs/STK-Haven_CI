import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';
import 'package:core/features/coach/application/coach_measurement_provider.dart';
import 'package:gym_tracker/features/coach/presentation/pages/coach_measurement_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Identity extends AppIdentityNotifier{
  @override AppIdentityState build()=>const AppIdentityState(sessionKind:AppSessionKind.permanent,userId:'client');
}
class _Measurements extends BodyMeasurementNotifier {
  @override List<BodyMeasurement> build()=>[BodyMeasurement(id:'private',date:DateTime(2026,11,25),weightKg:70,waistCm:80)];
}
class _Service implements CoachMeasurementService{
  CoachMeasurementShare? snapshot;
  int shares=0;
  @override Never get client=>throw UnimplementedError();
  @override Future<CoachMeasurementShare?> read(String relationshipId) async=>snapshot;
  @override Future<void> share(String relationshipId,DateTime measuredAt,Map<String,double> values) async{
    shares++;snapshot=CoachMeasurementShare(relationshipId:relationshipId,measuredAt:measuredAt,sharedAt:DateTime(2026,11,26),values:values);
  }
  @override Future<void> clear(String relationshipId)async{snapshot=null;}
}
void main(){
  testWidgets('client explicitly chooses fields before any upload and can withdraw shared copy',(tester)async{
    final service=_Service();
    await tester.pumpWidget(ProviderScope(overrides:[
      appIdentityProvider.overrideWith(_Identity.new),
      bodyMeasurementProvider.overrideWith(_Measurements.new),
      coachMeasurementServiceProvider.overrideWithValue(service),
    ],child:const MaterialApp(home:CoachMeasurementPage(relationshipId:'r',clientUserId:'client',viewerUserId:'client'))));
    await tester.pumpAndSettle();
    expect(service.shares,0);
    await tester.tap(find.text('Elegir medidas para compartir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 campos registrados'));
    await tester.pumpAndSettle();
    final submit=find.widgetWithText(FilledButton,'Compartir');
    expect(tester.widget<FilledButton>(submit).onPressed,isNull);
    await tester.tap(find.text('Cintura (cm)'));
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(service.shares,1);
    expect(service.snapshot!.values,{'waistCm':80.0});
    expect(find.text('Peso (kg)'),findsNothing);
    await tester.ensureVisible(find.text('Retirar copia compartida'));
    await tester.tap(find.text('Retirar copia compartida'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton,'Retirar'));
    await tester.pumpAndSettle();
    expect(service.snapshot,isNull);
  });
}
