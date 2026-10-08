import 'dart:async';
import 'dart:convert';

import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/features/coach_pro/application/coach_pro_program_revision_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_program_revision_service.dart';
import 'package:core/features/coach_pro/domain/coach_pro_program_revision.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_program_revision_page.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Identity extends AppIdentityNotifier {
  @override
  AppIdentityState build() => const AppIdentityState(
        sessionKind: AppSessionKind.permanent,
        userId: 'coach',
      );

  void signOutForTest() => state = const AppIdentityState();
}

const CoachProProgramRevisionHistoryQuery _historyQuery = (
  relationshipId: 'rel',
  assignmentId: 'program',
  offset: 0,
);

const CoachProProgramRevisionDetailQuery _detailQuery = (
  relationshipId: 'rel',
  assignmentId: 'program',
  revisionId: 'rev-2',
  routineId: null,
  offset: 0,
);

CoachProProgramRevisionHistoryResult _historyPage({
  int total = 2,
}) =>
    CoachProProgramRevisionHistoryResult(
      assignmentId: 'program',
      relationshipId: 'rel',
      currentAssignmentVersion: 2,
      totalCount: total,
      items: [
        CoachProProgramRevisionSummary(
          id: 'rev-2',
          revisionNumber: 2,
          previousRevisionId: 'rev-1',
          source: CoachProProgramRevisionSource.coachRevision,
          observedAssignmentVersion: 2,
          recordedAt: DateTime(2026, 10, 6),
          authoredAt: DateTime(2026, 10, 6),
        ),
      ],
    );

CoachProProgramRevisionPage _revisionPage(
  String revisionId, {
  String? routineId,
}) {
  final previous = revisionId == 'rev-1';
  if (routineId != null) {
    return CoachProProgramRevisionPage(
      assignmentId: 'program',
      relationshipId: 'rel',
      revisionId: revisionId,
      revisionNumber: previous ? 1 : 2,
      previousRevisionId: previous ? null : 'rev-1',
      source: previous
          ? CoachProProgramRevisionSource.legacyBaseline
          : CoachProProgramRevisionSource.coachRevision,
      observedAssignmentVersion: previous ? 1 : 2,
      name: 'Plan fuerza',
      durationWeeks: previous ? 8 : 10,
      trainingWeekdays: const {1, 3, 5},
      startsOn: DateTime(2026, 10, 6),
      recordedAt: DateTime(2026, 10, 6),
      authoredAt: previous ? null : DateTime(2026, 10, 6),
      routineName: 'Upper A',
      totalCount: 1,
      exercises: [
        AssignedExerciseSnapshot.fromJson({
          'id': 'exercise',
          'name': 'Press banca',
          'position': 0,
          'target_sets': 4,
          'target_reps_min': 6,
          'target_reps_max': 8,
          'rest_seconds': 180,
          'warmup_sets': 2,
          'approach_sets': 1,
          'unilateral': false,
          'unilateral_target': 'other',
        }),
      ],
    );
  }
  return CoachProProgramRevisionPage(
    assignmentId: 'program',
    relationshipId: 'rel',
    revisionId: revisionId,
    revisionNumber: previous ? 1 : 2,
    previousRevisionId: previous ? null : 'rev-1',
    source: previous
        ? CoachProProgramRevisionSource.legacyBaseline
        : CoachProProgramRevisionSource.coachRevision,
    observedAssignmentVersion: previous ? 1 : 2,
    name: 'Plan fuerza',
    durationWeeks: previous ? 8 : 10,
    trainingWeekdays: const {1, 3, 5},
    startsOn: DateTime(2026, 10, 6),
    recordedAt: DateTime(2026, 10, 6),
    authoredAt: previous ? null : DateTime(2026, 10, 6),
    totalCount: 1,
    routines: const [
      CoachProProgramRevisionRoutineSummary(
        id: 'routine',
        name: 'Upper A',
        position: 0,
      ),
    ],
  );
}

class _Service implements CoachProProgramRevisionService {
  final pending = Completer<CoachProProgramRevisionHistoryResult>();
  int calls = 0;

  @override
  Never get client => throw UnimplementedError();

  @override
  Future<CoachProProgramRevisionHistoryResult> list(
    CoachProProgramRevisionHistoryQuery query,
  ) {
    calls++;
    return pending.future;
  }

  @override
  Future<CoachProProgramRevisionPage> load(
    CoachProProgramRevisionDetailQuery query,
  ) =>
      throw UnimplementedError();
}

void main() {
  test('HTTP contract validates history/detail scope and authorship', () async {
    final requests = <http.Request>[];
    String? corrupt;
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final params = jsonDecode(request.body) as Map<String, dynamic>;
        final history = request.url.path.endsWith(
          'stk_list_coach_pro_program_revisions',
        );
        if (history) {
          return http.Response(
            jsonEncode({
              'assignment_id':
                  corrupt == 'assignment' ? 'other' : 'program',
              'relationship_id': 'rel',
              'current_assignment_version': 2,
              'total_count': 2,
              'items': [
                {
                  'id': 'rev-2',
                  'revision_number': 2,
                  'previous_revision_id': 'rev-1',
                  'source_kind': 'coach_revision',
                  'observed_assignment_version': 2,
                  'recorded_at': '2026-10-06T12:00:00Z',
                  'authored_at':
                      corrupt == 'author' ? null : '2026-10-06T11:00:00Z',
                },
              ],
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }

        final routineId = params['p_revision_routine_id'];
        return http.Response(
          jsonEncode({
            'assignment_id': 'program',
            'relationship_id': 'rel',
            'revision_id': 'rev-2',
            'revision_number': 2,
            'previous_revision_id': 'rev-1',
            'source_kind': 'coach_revision',
            'observed_assignment_version': 2,
            'name': 'Plan fuerza',
            'duration_weeks': 10,
            'training_weekdays': [1, 3, 5],
            'starts_on': '2026-10-06',
            'recorded_at': '2026-10-06T12:00:00Z',
            'authored_at': '2026-10-06T11:00:00Z',
            'routine': routineId == null
                ? null
                : {
                    'id': corrupt == 'routine' ? 'other' : 'routine',
                    'name': 'Upper A',
                    'position': 0,
                  },
            'items': [
              if (routineId == null)
                {'id': 'routine', 'name': 'Upper A', 'position': 0}
              else
                {
                  'id': 'exercise',
                  'name': 'Press banca',
                  'position': 0,
                  'muscle_group': 'Pecho',
                  'equipment': 'Barra',
                  'target_sets': 4,
                  'target_reps_min': 6,
                  'target_reps_max': 8,
                  'rest_seconds': 180,
                  'warmup_sets': 2,
                  'approach_sets': 1,
                  'unilateral': false,
                  'unilateral_target': 'other',
                  'superset_key': null,
                },
            ],
            'total_count': 1,
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);

    final service = CoachProProgramRevisionService(client);
    final history = await service.list(_historyQuery);
    expect(history.items.single.revisionNumber, 2);
    expect(
      jsonDecode(requests.first.body),
      {
        'p_relationship_id': 'rel',
        'p_assignment_id': 'program',
        'p_limit': 25,
        'p_offset': 0,
      },
    );

    final detail = await service.load(_detailQuery);
    expect(detail.routines.single.name, 'Upper A');
    expect(detail.previousRevisionId, 'rev-1');
    expect(
      jsonDecode(requests.last.body),
      {
        'p_relationship_id': 'rel',
        'p_assignment_id': 'program',
        'p_revision_id': 'rev-2',
        'p_revision_routine_id': null,
        'p_limit': 25,
        'p_offset': 0,
      },
    );

    final routine = await service.load((
      relationshipId: 'rel',
      assignmentId: 'program',
      revisionId: 'rev-2',
      routineId: 'routine',
      offset: 25,
    ));
    expect(routine.exercises.single.name, 'Press banca');
    expect(jsonDecode(requests.last.body)['p_offset'], 25);

    corrupt = 'assignment';
    await expectLater(service.list(_historyQuery), throwsFormatException);
    corrupt = 'author';
    await expectLater(service.list(_historyQuery), throwsFormatException);
    corrupt = 'routine';
    await expectLater(
      service.load((
        relationshipId: 'rel',
        assignmentId: 'program',
        revisionId: 'rev-2',
        routineId: 'routine',
        offset: 0,
      )),
      throwsFormatException,
    );
  });

  test('sign-out discards a pending revision history request', () async {
    final service = _Service();
    final container = ProviderContainer(
      overrides: [
        appIdentityProvider.overrideWith(_Identity.new),
        coachProProgramRevisionServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final provider = coachProProgramRevisionHistoryProvider(_historyQuery);
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
    expect(await container.read(provider.future), isNull);

    service.pending.complete(_historyPage());
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).value, isNull);
    expect(service.calls, 1);
  });

  testWidgets(
    'history opens immutable detail, comparison and prescription',
    (tester) async {
      final historyQueries = <CoachProProgramRevisionHistoryQuery>[];
      final detailQueries = <CoachProProgramRevisionDetailQuery>[];
      final container = ProviderContainer(
        overrides: [
          appIdentityProvider.overrideWith(_Identity.new),
          coachProProgramRevisionHistoryProvider.overrideWith(
            (ref, query) async {
              historyQueries.add(query);
              return _historyPage(total: 26);
            },
          ),
          coachProProgramRevisionDetailProvider.overrideWith(
            (ref, query) async {
              detailQueries.add(query);
              return _revisionPage(
                query.revisionId,
                routineId: query.routineId,
              );
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CoachProProgramRevisionHistoryPage(
              relationshipId: 'rel',
              assignmentId: 'program',
              assignmentName: 'Plan fuerza',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Revisión 2'), findsOneWidget);
      expect(find.textContaining('coach asignado'), findsOneWidget);
      expect(find.textContaining('no cambia el programa instalado'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(historyQueries.last.offset, 25);

      await tester.tap(find.text('Revisión 2'));
      await tester.pumpAndSettle();

      expect(find.text('Detalle de revisión'), findsOneWidget);
      expect(find.textContaining('Comparación básica con revisión 1'), findsOneWidget);
      expect(find.textContaining('Duración: 8 → 10 semanas'), findsOneWidget);
      expect(detailQueries.any((query) => query.revisionId == 'rev-1'), isTrue);

      await tester.tap(find.text('Upper A'));
      await tester.pumpAndSettle();

      expect(find.text('Rutina de la revisión'), findsOneWidget);
      expect(find.text('Press banca'), findsOneWidget);
      expect(find.text('4 series · 6–8 repeticiones'), findsOneWidget);
      expect(detailQueries.last.routineId, 'routine');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('history error never exposes backend detail', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appIdentityProvider.overrideWith(_Identity.new),
        coachProProgramRevisionHistoryProvider.overrideWith(
          (ref, query) => throw StateError('private backend message'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: CoachProProgramRevisionHistoryPage(
            relationshipId: 'rel',
            assignmentId: 'program',
            assignmentName: 'Plan fuerza',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('private backend message'), findsNothing);
    expect(find.textContaining('No se pudo consultar el historial'), findsOneWidget);
  });
}
