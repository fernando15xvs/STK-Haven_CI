import 'dart:async';
import 'dart:convert';
import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/coach_assigned_task.dart';
import 'package:core/features/coach_pro/application/coach_pro_task_comments_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_task_service.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_task_comments_page.dart';
import 'package:core/features/coach_pro/data/coach_pro_task_comments_service.dart';
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
const CoachProTaskQuery _query = (relationshipId: 'rel', taskId: 'task', offset: 0);
Map<String, dynamic> _comment() => {
  'id': 'comment', 'task_id': 'task', 'author_user_id': 'client', 'body': 'Comentario compartido',
  'occurrence_date': null, 'created_at': '2026-10-03T00:00:00Z',
};
CoachProTaskCommentsPage _page({bool empty = false}) => CoachProTaskCommentsPage(
  coachUserId: 'coach', totalCount: empty ? 0 : 26,
  items: empty ? const [] : [CoachTaskComment.fromJson(_comment())]);
class _Service implements CoachProTaskCommentsService {
  final pending = Completer<CoachProTaskCommentsPage>();
  int calls = 0;
  int writes = 0;
  String? sentBody;
  final sent = Completer<void>();
  @override
  Future<void> add({required String relationshipId, required String taskId, required String body}) {
    writes++; sentBody = body;
    expect(relationshipId, 'rel'); expect(taskId, 'task');
    return sent.future;
  }
  @override
  Never get client => throw UnimplementedError();
  @override
  Future<CoachProTaskCommentsPage> load(CoachProTaskQuery query) { calls++; return pending.future; }
}
Future<ProviderContainer> _mount(WidgetTester tester, {
  double width = 390, double scale = 1,
  required Future<CoachProTaskCommentsPage?> Function(CoachProTaskQuery) load,
}) async {
  tester.view.physicalSize = Size(width, 1100); tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [appIdentityProvider.overrideWith(_Identity.new),
    coachProTaskCommentsProvider.overrideWith((ref, query) => load(query))]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale)), child: child!),
    home: const CoachProTaskCommentsScreen(relationshipId: 'rel', taskId: 'task'))));
  await tester.pump(); return container;
}
void main() {
  test('write uses scoped RPC, trims body and rejects invalid input before HTTP', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.test', 'test-key', httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode('comment-id'), 200, request: request,
        headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final service = CoachProTaskCommentsService(client);
    await service.add(relationshipId: 'rel', taskId: 'task', body: '  Hola  ');
    expect(requests.single.url.path, '/rest/v1/rpc/stk_add_coach_pro_task_comment');
    expect(jsonDecode(requests.single.body), {'p_relationship_id': 'rel', 'p_task_id': 'task', 'p_body': 'Hola'});
    for (final body in ['   ', 'a' * 2001]) {
      await expectLater(service.add(relationshipId: 'rel', taskId: 'task', body: body), throwsFormatException);
    }
    expect(requests, hasLength(1));
    await service.add(relationshipId: 'rel', taskId: 'task', body: '😀' * 2000);
    expect(requests, hasLength(2));
  });
  for (final outcome in ['success', 'error', 'signout']) {
    testWidgets('write $outcome prevents duplicate submits and revalidates safely', (tester) async {
      final service = _Service(); int loads = 0;
      final container = ProviderContainer(overrides: [appIdentityProvider.overrideWith(_Identity.new),
        coachProTaskCommentsServiceProvider.overrideWithValue(service),
        coachProTaskCommentsProvider.overrideWith((ref, query) async { loads++; return _page(); })]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(
        home: CoachProTaskCommentsScreen(relationshipId: 'rel', taskId: 'task'))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar comentario')); await tester.pump();
      expect(find.text('Escribe entre 1 y 2000 caracteres.'), findsOneWidget);
      expect(service.writes, 0);
      await tester.enterText(find.byType(TextField), 'Un mensaje');
      await tester.tap(find.text('Enviar comentario')); await tester.pump();
      await tester.tap(find.text('Enviando…')); await tester.pump();
      expect(service.writes, 1); expect(service.sentBody, 'Un mensaje');
      if (outcome == 'signout') {
        (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
        await tester.pumpAndSettle();
      }
      if (outcome == 'error') { service.sent.completeError(StateError('private server error')); }
      else { service.sent.complete(); }
      await tester.pumpAndSettle();
      expect(find.textContaining('private server error'), findsNothing);
      expect(find.text('Un mensaje'), findsNothing);
      if (outcome == 'signout') {
        expect(find.text('Comentario enviado.'), findsNothing);
        expect(find.byType(TextField), findsNothing); expect(loads, 1);
      } else {
        expect(loads, 2);
        expect(find.text(outcome == 'success' ? 'Comentario enviado.' :
          'No se pudo confirmar el envío. Revisa los comentarios antes de volver a enviarlo.'), findsOneWidget);
        expect(find.text('Enviar comentario'), findsOneWidget);
      }
    });
  }

  test('comments RPC validates scope, authors, dates and bounded immutable pages', () async {
    final requests = <http.Request>[];
    String? corrupt; bool empty = false;
    final client = SupabaseClient('https://example.test', 'test-key', httpClient: MockClient((request) async {
      requests.add(request);
      final item = _comment();
      final payload = <String, dynamic>{'relationship_id': 'rel', 'task_id': 'task',
        'coach_user_id': 'coach', 'client_user_id': 'client', 'total_count': 26};
      if (corrupt == 'task') item['task_id'] = 'other';
      if (corrupt == 'author') item['author_user_id'] = 'other';
      if (corrupt == 'date') item['created_at'] = null;
      if (corrupt == 'occurrence') item['occurrence_date'] = 'bad';
      if (corrupt == 'body') item['body'] = '';
      if (corrupt == 'relationship') payload['relationship_id'] = 'other';
      if (corrupt == 'count') payload['total_count'] = -1;
      payload['items'] = empty ? [] : [item];
      return http.Response(jsonEncode(payload),200,request: request,
        headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final service = CoachProTaskCommentsService(client);
    final page = await service.load(_query);
    expect(requests.single.url.path, '/rest/v1/rpc/stk_list_coach_pro_task_comments');
    expect(jsonDecode(requests.single.body), {'p_relationship_id': 'rel', 'p_task_id': 'task',
      'p_limit': 25, 'p_offset': 0});
    expect(page.items.single.occurrenceDate, isNull);
    expect(page.items.single.body, 'Comentario compartido');
    expect(() => page.items.clear(), throwsUnsupportedError);
    for (final field in ['task', 'author', 'date', 'occurrence', 'body', 'relationship', 'count']) {
      corrupt = field; await expectLater(service.load(_query), throwsFormatException);
    }
    corrupt = null; empty = true;
    final last = await service.load((relationshipId: 'rel', taskId: 'task', offset: 50));
    expect(last.items, isEmpty); expect(last.totalCount, 26);
    expect(jsonDecode(requests.last.body)['p_offset'], 50);
  });
  test('sign-out discards a late comments response', () async {
    final service = _Service();
    final container = ProviderContainer(overrides: [appIdentityProvider.overrideWith(_Identity.new),
      coachProTaskCommentsServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
    final provider = coachProTaskCommentsProvider(_query);
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
    expect(await container.read(provider.future), isNull);
    service.pending.complete(_page()); await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).value, isNull); expect(service.calls, 1);
  });
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('comments at $width paginate without accumulating', (tester) async {
      final queries = <CoachProTaskQuery>[];
      await _mount(tester, width: width, load: (query) async { queries.add(query); return _page(); });
      expect(find.text('Comentario compartido'), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
      expect(queries, hasLength(1));
      await tester.ensureVisible(find.text('Siguiente')); await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente')); await tester.pumpAndSettle();
      expect(queries.last.offset, 25);
      expect(find.text('Comentario compartido'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('refresh immediately redacts comments and hides server errors', (tester) async {
    final pending = Completer<CoachProTaskCommentsPage?>(); bool refreshing = false;
    await _mount(tester, load: (_) => refreshing ? pending.future : Future.value(_page()));
    refreshing = true; await tester.tap(find.text('Actualizar')); await tester.pump();
    expect(find.text('Comentario compartido'), findsNothing);
    pending.completeError(StateError('private server detail')); await tester.pumpAndSettle();
    expect(find.textContaining('private server detail'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Comentario compartido'), findsNothing);
  });
  testWidgets('empty comments and large text, sign-out clears the page', (tester) async {
    final container = await _mount(tester, width: 320, scale: 1.8, load: (_) async => _page(empty: true));
    expect(find.text('Todavía no hay comentarios.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
    await tester.pumpAndSettle();
    expect(find.text('Siguiente'), findsNothing);
    expect(find.textContaining('cuenta permanente'), findsOneWidget);
  });
}
