import 'dart:async';
import 'dart:convert';
import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/nutrition_guidance.dart';
import 'package:core/features/coach_pro/application/coach_pro_nutrition_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_nutrition_service.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_nutrition_page.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_nutrition_versions_page.dart';
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
  test('version history validates scope, ordering and pagination metadata', () async {
    String? corrupt; bool empty = false; late http.Request last;
    final client = SupabaseClient('https://example.test', 'test-key', httpClient: MockClient((request) async {
      last = request;
      final row = <String, dynamic>{'version': 2, 'title': 'Versión compartida', 'created_at': '2026-10-01T00:00:00Z'};
      final data = <String, dynamic>{'relationship_id': 'rel', 'plan_id': 'plan', 'client_user_id': 'client',
        'current_version': 2, 'total_count': 2, 'items': empty ? [] : [row]};
      if (corrupt == 'scope') data['relationship_id'] = 'other';
      if (corrupt == 'plan') data['plan_id'] = 'other';
      if (corrupt == 'client') data['client_user_id'] = 'other';
      if (corrupt == 'future') row['version'] = 3;
      if (corrupt == 'date') row['created_at'] = null;
      if (corrupt == 'title') row['title'] = '';
      if (corrupt == 'count') data['total_count'] = 3;
      if (corrupt == 'order') data['items'] = [row, row];
      return http.Response(jsonEncode(data), 200, request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose); final service = CoachProNutritionService(client);
    final page = await service.listVersions(_query);
    expect(last.url.path, endsWith('stk_list_coach_pro_nutrition_versions'));
    expect(jsonDecode(last.body), {'p_relationship_id': 'rel', 'p_plan_id': 'plan', 'p_limit': 25, 'p_offset': 0});
    expect(page.items.single.version, 2); expect(page.currentVersion, 2);
    expect(() => page.items.clear(), throwsUnsupportedError);
    for (final key in ['scope', 'plan', 'client', 'future', 'date', 'title', 'count', 'order']) {
      corrupt = key; await expectLater(service.listVersions(_query), throwsFormatException);
    }
    corrupt = null; empty = true;
    final later = await service.listVersions((relationshipId: 'rel', clientUserId: 'client', planId: 'plan', version: 1, offset: 25));
    expect(later.items, isEmpty); expect(later.totalCount, 2); expect(jsonDecode(last.body)['p_offset'], 25);
  });
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('history at $width pages and returns to an empty page safely', (tester) async {
      tester.view.physicalSize = Size(width, 1300); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final offsets = <int>[];
      await tester.pumpWidget(ProviderScope(overrides: [appIdentityProvider.overrideWith(_Identity.new),
        coachProNutritionVersionsProvider.overrideWith((ref, q) async {
          offsets.add(q.offset); return CoachProNutritionVersionsPage(q.offset == 0
            ? [CoachProNutritionVersion(27, 'Título permitido', DateTime.utc(2026))] : [], 27, 27);
        })], child: const MaterialApp(home: CoachProNutritionVersionsScreen(query: _query))));
      await tester.pumpAndSettle(); expect(find.text('Versión 27 · Actual'), findsOneWidget);
      await tester.tap(find.text('Siguiente')); await tester.pumpAndSettle();
      expect(offsets.last, 25); expect(find.text('Título permitido'), findsNothing);
      expect(find.textContaining('Esta página está vacía'), findsOneWidget);
      await tester.tap(find.text('Anterior')); await tester.pumpAndSettle();
      expect(offsets.last, 0); expect(tester.takeException(), isNull);
    });
  }
  testWidgets('selecting history resets meal offset and pins the selected version', (tester) async {
    final queries = <CoachProNutritionQuery>[];
    await tester.pumpWidget(ProviderScope(overrides: [appIdentityProvider.overrideWith(_Identity.new),
      coachProNutritionProvider.overrideWith((ref, q) async { queries.add(q); return _page(); }),
      coachProNutritionVersionsProvider.overrideWith((ref, q) async => CoachProNutritionVersionsPage(
        [CoachProNutritionVersion(2, 'Otra versión', DateTime.utc(2026))], 2, 2))],
      child: const MaterialApp(home: CoachProNutritionDetailPage(query: _query))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Siguiente')); await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente')); await tester.pumpAndSettle(); expect(queries.last.offset, 5);
    await tester.ensureVisible(find.text('Ver versiones')); await tester.pumpAndSettle();
    await tester.tap(find.text('Ver versiones')); await tester.pumpAndSettle();
    await tester.tap(find.text('Consultar versión 2')); await tester.pumpAndSettle();
    expect(queries.last.version, 2); expect(queries.last.offset, 0);
    await tester.ensureVisible(find.text('Siguiente')); await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente')); await tester.pumpAndSettle();
    expect(queries.last.version, 2); expect(queries.last.offset, 5);
  });
  testWidgets('history refresh and signout redact previous metadata', (tester) async {
    bool refreshing = false; final pending = Completer<CoachProNutritionVersionsPage?>();
    final container = ProviderContainer(overrides: [appIdentityProvider.overrideWith(_Identity.new),
      coachProNutritionVersionsProvider.overrideWith((ref, q) => refreshing ? pending.future : Future.value(
        CoachProNutritionVersionsPage([CoachProNutritionVersion(1, 'Título privado', DateTime.utc(2026))], 1, 1)))]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: const MaterialApp(home: CoachProNutritionVersionsScreen(query: _query))));
    await tester.pumpAndSettle(); refreshing = true;
    await tester.tap(find.text('Actualizar')); await tester.pump(); expect(find.text('Título privado'), findsNothing);
    pending.completeError(StateError('private history')); await tester.pumpAndSettle();
    expect(find.textContaining('private history'), findsNothing); expect(find.text('Reintentar'), findsOneWidget);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest(); await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsNothing); expect(find.textContaining('cuenta permanente'), findsOneWidget);
  });
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
