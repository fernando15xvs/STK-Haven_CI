import 'dart:async';
import 'dart:convert';
import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/features/coach_pro/application/coach_pro_program_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_program_service.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_program_page.dart';
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
const CoachProProgramQuery _query = (relationshipId: 'rel', assignmentId: 'program', version: 2, routineId: null, offset: 0);
CoachProProgramPage _page({bool exercises = false, bool empty = false}) => CoachProProgramPage(
  name: 'Plan fuerza', version: 2, status: AssignedProgramStatus.accepted, totalCount: empty ? 0 : 26,
  routineName: exercises ? 'Rutina A' : null,
  routines: exercises || empty ? const [] : const [CoachProRoutineSummary('routine', 'Rutina A', 0)],
  exercises: !exercises || empty ? const [] : [AssignedExerciseSnapshot.fromJson({
    'id': 'exercise', 'name': 'Sentadilla', 'position': 0, 'target_sets': 3,
    'target_reps_min': 8, 'target_reps_max': 12, 'rest_seconds': 90,
  })]);

class _Service implements CoachProProgramService {
  final pending = Completer<CoachProProgramPage>();
  int calls = 0;
  @override
  Never get client => throw UnimplementedError();
  @override
  Future<CoachProProgramPage> load(CoachProProgramQuery query) { calls++; return pending.future; }
}

Future<ProviderContainer> _mount(WidgetTester tester, {
  double width = 390, double scale = 1,
  required Future<CoachProProgramPage?> Function(CoachProProgramQuery) load,
}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    appIdentityProvider.overrideWith(_Identity.new),
    coachProProgramPageProvider.overrideWith((ref, query) => load(query)),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale)), child: child!),
    home: const CoachProProgramDetailPage(relationshipId: 'rel', assignmentId: 'program', version: 2))));
  await tester.pump();
  return container;
}

void main() {
  test('HTTP contract pins scope/version, bounds pages and rejects mismatched payload', () async {
    final requests = <http.Request>[];
    bool badVersion = false;
    bool badRoutine = false;
    final client = SupabaseClient('https://example.test', 'test-key', httpClient: MockClient((request) async {
      requests.add(request);
      final params = jsonDecode(request.body) as Map;
      final exercise = params['p_routine_id'] != null;
      return http.Response(jsonEncode({
        'assignment_id': 'program', 'relationship_id': 'rel', 'name': 'Plan fuerza',
        'version': badVersion ? 3 : 2, 'status': 'accepted', 'total_count': 26,
        'routine': exercise ? {'id': badRoutine ? 'other' : 'routine', 'name': 'Rutina A'} : null,
        'items': [{'id': exercise ? 'exercise' : 'routine', 'name': exercise ? 'Sentadilla' : 'Rutina A',
          'position': 0, if (exercise) ...{'target_sets': 3, 'target_reps_min': 8,
            'target_reps_max': 12, 'rest_seconds': 90, 'warmup_sets': 1, 'approach_sets': 0}}],
      }), 200, request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final service = CoachProProgramService(client);
    final page = await service.load(_query);
    expect(page.routines.single.id, 'routine');
    expect(page.exercises, isEmpty);
    expect(jsonDecode(requests.single.body), {'p_relationship_id': 'rel', 'p_assignment_id': 'program',
      'p_version': 2, 'p_routine_id': null, 'p_limit': 25, 'p_offset': 0});
    const exerciseQuery = (relationshipId: 'rel', assignmentId: 'program', version: 2, routineId: 'routine', offset: 25);
    final exercises = await service.load(exerciseQuery);
    expect(exercises.exercises.single.targetSets, 3);
    expect(exercises.routines, isEmpty);
    expect(jsonDecode(requests.last.body)['p_offset'], 25);
    badVersion = true;
    await expectLater(service.load(_query), throwsFormatException);
    badVersion = false; badRoutine = true;
    await expectLater(service.load(exerciseQuery), throwsFormatException);
  });

  test('sign-out invalidates pending program request without retaining result', () async {
    final service = _Service();
    final container = ProviderContainer(overrides: [appIdentityProvider.overrideWith(_Identity.new),
      coachProProgramServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
    final provider = coachProProgramPageProvider(_query);
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
    expect(await container.read(provider.future), isNull);
    service.pending.complete(_page());
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).value, isNull);
    expect(service.calls, 1);
  });

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('program at $width loads exercises on demand with pinned version', (tester) async {
      final queries = <CoachProProgramQuery>[];
      await _mount(tester, width: width, load: (query) async {
        queries.add(query); return _page(exercises: query.routineId != null);
      });
      expect(find.text('Rutina A'), findsOneWidget);
      expect(find.text('Sentadilla'), findsNothing);
      expect(queries, hasLength(1));
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(queries.last.offset, 25);
      await tester.tap(find.text('Rutina A'));
      await tester.pumpAndSettle();
      expect(queries.last.routineId, 'routine');
      expect(queries.last.offset, 0);
      expect(queries.last.version, 2);
      expect(find.text('Sentadilla'), findsOneWidget);
      expect(find.text('3 series · 8–12 repeticiones'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('refresh clears content and explains changed-version recovery', (tester) async {
    final pending = Completer<CoachProProgramPage?>();
    bool refreshing = false;
    await _mount(tester, load: (_) => refreshing ? pending.future : Future.value(_page()));
    refreshing = true;
    await tester.tap(find.text('Actualizar'));
    await tester.pump();
    expect(find.text('Plan fuerza'), findsNothing);
    pending.completeError(StateError('private backend message'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private backend message'), findsNothing);
    expect(find.textContaining('vuelve a la ficha'), findsOneWidget);
    expect(find.text('Plan fuerza'), findsNothing);
  });
  testWidgets('empty state at large text is usable and sign-out removes data', (tester) async {
    final container = await _mount(tester, width: 320, scale: 1.8, load: (_) async => _page(empty: true));
    expect(find.text('No hay elementos en esta sección.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
    await tester.pumpAndSettle();
    expect(find.text('Plan fuerza'), findsNothing);
    expect(find.textContaining('cuenta permanente'), findsOneWidget);
  });
}
