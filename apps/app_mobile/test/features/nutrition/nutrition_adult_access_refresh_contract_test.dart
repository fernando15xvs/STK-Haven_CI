import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('nutrition numeric permission is refreshed and fail closed',(){
    final mobile=File(
      'lib/features/nutrition/presentation/pages/nutrition_intelligence_page_mobile.dart',
    ).readAsStringSync();
    expect(mobile,contains('onAuthStateChange.listen('));
    expect(mobile,contains('onError:(Object error,StackTrace stackTrace)'));
    expect(mobile,contains('AppLifecycleState.resumed'));
    expect(mobile,contains('snapshot.connectionState == ConnectionState.done'));
    expect(mobile,contains('snapshot.data == true'));
    expect(mobile,contains('unawaited(_authSubscription?.cancel())'));
    expect(mobile,contains('onRefreshAdultAccess: _refreshAdultAccess'));
    expect(mobile,contains('nutrition_account_'));
    expect(mobile,contains('Supabase.instance.client.auth.currentUser?.id'));
  });

  test('revoked grant hides formerly numeric cached results',(){
    final core=File(
      '../../packages/core/lib/features/nutrition/presentation/pages/nutrition_intelligence_page.dart',
    ).readAsStringSync();
    expect(core,contains('didUpdateWidget(covariant NutritionIntelligencePage'));
    expect(core,contains('oldWidget.verifiedAdultNutritionAccess'));
    expect(core,contains('_foodEstimate=null;'));
    expect(core,contains('_energyEstimate=null;'));
    expect(core,contains('onRefreshAdultAccess'));
    expect(core,contains('Volver a comprobar acceso'));
    expect(core,contains('Acceso calórico pendiente de verificación'));
    expect(core,contains('proceso externo de verificación no está disponible'));
    expect(core,contains('no basta con cambiar tu fecha de nacimiento'));

    expect(core,contains('estimate.numericNutritionAvailable && !_hasAdultNumericAccess'));
  });
}
