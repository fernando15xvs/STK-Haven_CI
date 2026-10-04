import 'dart:async';
import 'dart:convert';
import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/nutrition_guidance.dart';
import 'package:core/features/coach_pro/application/coach_pro_nutrition_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_nutrition_service.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_nutrition_page.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Identity extends AppIdentityNotifier {
  @override
  AppIdentityState build() => const AppIdentityState(sessionKind: AppSessionKind.permanent, userId: 'coach');
  void signOutForTest() => state = const AppIdentityState();
}
const CoachProNutritionQuery _query = (relationshipId: 'rel', clientUserId: 'client', planId: 'plan', version: 1, offset: 0);
Map<String, dynamic> _json() => {'id': 'plan', 'relationship_id': 'rel', 'coach_user_id': 'coach',
  'client_user_id': 'client', 'status': 'archived', 'current_version': 2, 'version': 1,
  'title': 'Orientación compartida', 'updated_at': '2026-10-01T00:00:00Z', 'created_at': '2026-10-01T00:00:00Z',
  'overview': 'Texto de la versión uno', 'hydration_notes': '', 'general_notes': '',
  'scope_notice': NutritionGuidancePlan.defaultScopeNotice,
  'meals': [{'id': 'meal', 'position': 0, 'name': 'Comida compartida', 'timing_label': '', 'notes': '',
    'items': [{'id': 'item', 'position': 0, 'food_example': 'Ejemplo compartido', 'serving_note': ''}]}]};
CoachProNutritionPage _page() => CoachProNutritionPage(NutritionGuidancePlan.fromJson(_json()), 6);
void main() {
  test('nutrition RPCs preserve pinned version and reject mismatched or malformed payloads', () async {
    final requests = <http.Request>[]; String? corrupt; bool empty = false;
    final client = SupabaseClient('https://example.test', 'test-key', httpClient: MockClient((request) async {
      requests.add(request); final plan = _json();
      if (corrupt == 'relationship') plan['relationship_id'] = 'other';
      if (corrupt == 'client') plan['client_user_id'] = 'other';
      if (corrupt == 'version') plan['version'] = 2;
      if (corrupt == 'date') plan['created_at'] = null;
      if (corrupt == 'status') plan['status'] = 'unknown';
      if (corrupt == 'items') (plan['meals'] as List).first['items'] = [null];
      if (empty) plan['meals'] = [];
      final listing = request.url.path.endsWith('stk_list_coach_pro_nutrition');
      return http.Response(jsonEncode(listing ? {'relationship_id': 'rel', 'client_user_id': 'client',
        'items': empty ? [] : [plan], 'total_count': 27} : {'plan': plan, 'total_count': 6}),
        200, request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose); final service = CoachProNutritionService(client);
    final list = await service.list('rel', 'client', offset: 25);
    expect(list.totalCount, 27); expect(list.items.single.currentVersion, 2);
    expect(() => list.items.clear(), throwsUnsupportedError);
    expect(jsonDecode(requests.last.body), {'p_relationship_id': 'rel', 'p_limit': 25, 'p_offset': 25});
    final page = await service.load(_query);
    expect(page.plan.version, 1); expect(page.plan.currentVersion, 2);
    expect(page.plan.meals.single.items.single.foodExample, 'Ejemplo compartido');
    expect(jsonDecode(requests.last.body), {'p_relationship_id': 'rel', 'p_plan_id': 'plan', 'p_version': 1, 'p_offset': 0});
    for (final key in ['relationship', 'client', 'version', 'date', 'status', 'items']) {
      corrupt = key; await expectLater(service.load(_query), throwsFormatException);
    }
    corrupt = 'relationship'; await expectLater(service.list('rel', 'client'), throwsFormatException);
    corrupt = null; empty = true;
    expect((await service.list('rel', 'client', offset: 50)).totalCount, 27);
    expect((await service.load(_query)).plan.meals, isEmpty);
  });
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('nutrition detail at $width stays on the selected version while paging', (tester) async {
      tester.view.physicalSize = Size(width, 1300); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final queries = <CoachProNutritionQuery>[];
      await tester.pumpWidget(ProviderScope(overrides: [appIdentityProvider.overrideWith(_Identity.new),
        coachProNutritionProvider.overrideWith((ref, q) async { queries.add(q); return _page(); })],
        child: const MaterialApp(home: CoachProNutritionDetailPage(query: _query))));
      await tester.pumpAndSettle();
      expect(find.text('Archivada · Versión 1 de 2'), findsOneWidget);
      expect(find.text('Ejemplo compartido'), findsOneWidget);
      await tester.ensureVisible(find.text('Siguiente')); await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente')); await tester.pumpAndSettle();
      expect(queries.last.offset, 5); expect(queries.last.version, 1);
      expect(find.text('Ejemplo compartido'), findsOneWidget); expect(tester.takeException(), isNull);
    });
  }
  testWidgets('refresh redacts nutrition content and signout removes access', (tester) async {
    bool refreshing = false; final pending = Completer<CoachProNutritionPage?>();
    final container = ProviderContainer(overrides: [appIdentityProvider.overrideWith(_Identity.new),
      coachProNutritionProvider.overrideWith((ref, q) => refreshing ? pending.future : Future.value(_page()))]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: const MaterialApp(home: CoachProNutritionDetailPage(query: _query))));
    await tester.pumpAndSettle(); refreshing = true;
    await tester.tap(find.text('Actualizar')); await tester.pump();
    expect(find.text('Texto de la versión uno'), findsNothing);
    pending.completeError(StateError('private nutrition')); await tester.pumpAndSettle();
    expect(find.textContaining('private nutrition'), findsNothing); expect(find.text('Reintentar'), findsOneWidget);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest(); await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsNothing); expect(find.textContaining('cuenta permanente'), findsOneWidget);
  });
}
