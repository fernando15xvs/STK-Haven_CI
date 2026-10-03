import 'package:core/features/coach_pro/application/coach_pro_task_comments_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_task_comments_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/coach_assigned_task.dart';
import 'package:core/features/coach_pro/application/coach_pro_task_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_task_service.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_task_page.dart';
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
Map<String, dynamic> _taskJson() => {
  'id': 'task', 'relationship_id': 'rel', 'coach_user_id': 'coach', 'client_user_id': 'client',
  'title': 'Movilidad suave', 'category': 'Recovery', 'status': 'archived',
  'task_type': 'checklist', 'target_minutes': 10, 'recurrence_type': 'daily', 'weekdays': [],
  'starts_on': '2026-10-01', 'coach_instructions': 'Sin dolor',
  'created_at': '2026-10-01T00:00:00Z', 'updated_at': '2026-10-03T00:00:00Z',
};
Map<String, dynamic> _occurrenceJson() => {
  'id': 'occurrence', 'task_id': 'task', 'client_user_id': 'client',
  'occurrence_date': '2026-10-02', 'status': 'skipped', 'minutes_spent': 0,
  'completed_at': null, 'created_at': '2026-10-02T00:00:00Z',
};
CoachProTaskPage _page({bool empty = false}) => CoachProTaskPage(
  task: CoachAssignedTask.fromJson(_taskJson()), totalCount: empty ? 0 : 26,
  occurrences: empty ? const [] : [CoachTaskOccurrence.fromJson(_occurrenceJson())]);
class _Service implements CoachProTaskService {
  final pending = Completer<CoachProTaskPage>();
  int calls = 0;
  @override
  Never get client => throw UnimplementedError();
  @override
  Future<CoachProTaskPage> load(CoachProTaskQuery query) { calls++; return pending.future; }
}
Future<ProviderContainer> _mount(WidgetTester tester, {
  double width = 390, double scale = 1,
  required Future<CoachProTaskPage?> Function(CoachProTaskQuery) load,
}) async {
  tester.view.physicalSize = Size(width, 1100); tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [appIdentityProvider.overrideWith(_Identity.new),
    coachProTaskPageProvider.overrideWith((ref, query) => load(query))]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale)), child: child!),
    home: const CoachProTaskDetailPage(relationshipId: 'rel', taskId: 'task'))));
  await tester.pump(); return container;
}
void main() {
  testWidgets('comments are loaded only after explicit navigation', (tester) async {
    int calls = 0;
    final container = ProviderContainer(overrides: [appIdentityProvider.overrideWith(_Identity.new),
      coachProTaskPageProvider.overrideWith((ref, query) async => _page()),
      coachProTaskCommentsProvider.overrideWith((ref, query) async {
        calls++;
        expect(query.relationshipId, 'rel'); expect(query.taskId, 'task');
        return const CoachProTaskCommentsPage(items: [], totalCount: 0, coachUserId: 'coach');
      })]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(
      home: CoachProTaskDetailPage(relationshipId: 'rel', taskId: 'task'))));
    await tester.pumpAndSettle(); expect(calls, 0);
    await tester.tap(find.text('Ver comentarios')); await tester.pumpAndSettle();
    expect(calls, 1); expect(find.text('Todavía no hay comentarios.'), findsOneWidget);
  });
  test('targeted HTTP page preserves finalized status and rejects cross-task/client records', () async {
    final requests = <http.Request>[];
    String? corrupt;
    bool empty = false;
    final client = SupabaseClient('https://example.test', 'test-key', httpClient: MockClient((request) async {
      requests.add(request);
      final item = _occurrenceJson();
      final task = _taskJson();
      if (corrupt == 'task_id') item['task_id'] = 'other';
      if (corrupt == 'client_user_id') item['client_user_id'] = 'other';
      if (corrupt == 'date') item['occurrence_date'] = null;
      if (corrupt == 'status') item['status'] = 'unknown';
      if (corrupt == 'relationship') task['relationship_id'] = 'other';
      return http.Response(jsonEncode({'task': task, 'items': empty ? [] : [item], 'total_count': 26}),
        200, request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final service = CoachProTaskService(client);
    final page = await service.load(_query);
    expect(requests.single.url.path, '/rest/v1/rpc/stk_get_coach_pro_task_page');
    expect(jsonDecode(requests.single.body), {'p_relationship_id': 'rel', 'p_task_id': 'task',
      'p_limit': 25, 'p_offset': 0});
    expect(page.task.status, CoachAssignedTaskStatus.archived);
    expect(page.task.coachInstructions, 'Sin dolor');
    expect(page.occurrences.single.status, CoachTaskOccurrenceStatus.skipped);
    expect(page.occurrences.single.completedAt, isNull);
    expect(page.occurrences.single.minutesSpent, 0);
    expect(() => page.occurrences.clear(), throwsUnsupportedError);
    for (final field in ['task_id', 'client_user_id', 'date', 'status', 'relationship']) {
      corrupt = field;
      await expectLater(service.load(_query), throwsFormatException);
    }
    corrupt = null; empty = true;
    final last = await service.load((relationshipId: 'rel', taskId: 'task', offset: 50));
    expect(last.occurrences, isEmpty); expect(last.totalCount, 26);
    expect(jsonDecode(requests.last.body)['p_offset'], 50);
  });
  test('sign-out discards a late history response', () async {
    final service = _Service();
    final container = ProviderContainer(overrides: [appIdentityProvider.overrideWith(_Identity.new),
      coachProTaskServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
    final provider = coachProTaskPageProvider(_query);
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
    expect(await container.read(provider.future), isNull);
    service.pending.complete(_page()); await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).value, isNull); expect(service.calls, 1);
  });
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('task history at $width preserves archive and pages without accumulating', (tester) async {
      final queries = <CoachProTaskQuery>[];
      await _mount(tester, width: width, load: (query) async { queries.add(query); return _page(); });
      expect(find.text('Movilidad suave'), findsOneWidget);
      expect(find.textContaining('Archivada'), findsOneWidget);
      expect(find.text('Omitida'), findsOneWidget);
      expect(find.text('0 min registrados'), findsOneWidget);
      expect(queries, hasLength(1));
      await tester.ensureVisible(find.text('Siguiente')); await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente')); await tester.pumpAndSettle();
      expect(queries.last.offset, 25); expect(queries.last.taskId, 'task');
      expect(find.text('Omitida'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('refresh clears instructions and history before a denied response', (tester) async {
    final pending = Completer<CoachProTaskPage?>(); bool refreshing = false;
    await _mount(tester, load: (_) => refreshing ? pending.future : Future.value(_page()));
    refreshing = true; await tester.tap(find.text('Actualizar')); await tester.pump();
    expect(find.text('Sin dolor'), findsNothing); expect(find.text('Omitida'), findsNothing);
    pending.completeError(StateError('private server detail')); await tester.pumpAndSettle();
    expect(find.textContaining('private server detail'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Movilidad suave'), findsNothing);
  });
  testWidgets('empty history does not infer missed days, large text and sign-out remain safe', (tester) async {
    final container = await _mount(tester, width: 320, scale: 1.8, load: (_) async => _page(empty: true));
    expect(find.text('Todavía no hay registros para esta tarea.'), findsOneWidget);
    await tester.ensureVisible(find.text('Siguiente')); await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
    await tester.pumpAndSettle();
    expect(find.text('Sin dolor'), findsNothing); expect(find.text('Siguiente'), findsNothing);
    expect(find.textContaining('cuenta permanente'), findsOneWidget);
  });
}
