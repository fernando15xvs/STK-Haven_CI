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
    expect(mobile,contains('FutureBuilder<NutritionAdultCheck>'));
    expect(mobile,contains('NutritionAdultCheck.checking'));
    expect(mobile,contains('NutritionAdultCheck.unavailable'));
    expect(mobile,contains('status.allowsNumeric'));
    expect(mobile,contains('mobileAdultCheck: status'));
    expect(mobile,contains('_accessOwnerId = client.auth.currentUser?.id'));
    expect(mobile,contains('currentUid != _accessOwnerId'));
    expect(mobile,contains('_accessOwnerToken = client.auth.currentSession?.accessToken'));
    expect(mobile,contains('currentToken != _accessOwnerToken'));
    expect(mobile,contains('_saveNutritionIntent(intent, currentUid, currentToken)'));
    expect(mobile,contains('NutritionAdultCheck.signedOut'));
    expect(mobile,isNot(contains('snapshot.data == true')));
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
    // The old Core panel stays intact for non-mobile callers. Only Mobile
    // opts into the smaller typed panel with error-only retry.
    expect(core,contains('Volver a comprobar acceso'));
    expect(core,contains('mobileAdultCheck'));
    expect(core,contains('StkMobileNutritionAccessPanel('));
    expect(core,contains('Plan calórico pendiente de acceso'));
    expect(core,contains('Los objetivos numéricos requieren autorización vigente del servidor.'));
    expect(core,contains('no basta con cambiar tu fecha de nacimiento'));

    expect(core,contains('estimate.numericNutritionAvailable && !_hasAdultNumericAccess'));
    expect(core,contains('final freshVerified=await NutritionAdultAccessService('));
    expect(core,contains('!freshVerified || !_hasAdultNumericAccess'));
    expect(core,contains('Supabase.instance.client.auth.currentUser?.id!=repo.ownerId'));
    expect(core,contains('accessCheckedAt:DateTime.now().toUtc()'));
    expect(core,contains('ref.listen<NutritionAccessState>('));
    expect(core,contains('setState(_clearSensitiveSessionState);'));
    expect(core,contains('int _analysisEpoch=0;'));
    expect(core,contains('epoch!=_analysisEpoch'));
    expect(core,contains('final stillVerified=await NutritionAdultAccessService('));
    expect(core,contains('!stillVerified || !_hasAdultNumericAccess'));
    expect(core,contains('if(!_sameMutationSession(sessionAtStart))return;'));
    expect(core,contains('NutritionMutationSessionPolicy.isCurrent('));
    expect(core,contains('when !estimate.numericNutritionAvailable ||'));
    expect(core,contains('widget.onRefreshAdultAccess?.call()'));
  });
}
