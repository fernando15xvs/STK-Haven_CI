import 'dart:async';
import 'dart:convert';

import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/features/coach/application/coach_program_revision_acceptance_provider.dart';
import 'package:core/features/coach/data/coach_program_revision_acceptance_service.dart';
import 'package:core/features/coach/domain/coach_program_revision_acceptance.dart';
import 'package:core/features/coach/presentation/pages/coach_program_revision_review_page.dart';
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
        userId: 'client',
      );

  void signOutForTest() => state = const AppIdentityState();
}

class _PendingService implements CoachProgramRevisionAcceptanceService {
  final pending = Completer<CoachProgramRevisionState>();
  int calls = 0;

  @override
  Never get client => throw UnimplementedError();

  @override
  Future<CoachProgramRevisionState> loadState(String assignmentId) {
    calls++;
    return pending.future;
  }

  @override
  Future<ClientProgramRevisionPage> loadPage(
    ClientProgramRevisionPageQuery query,
  ) =>
      throw UnimplementedError();

  @override
  Future<AcceptedProgramRevisionSnapshot> loadAcceptedRevision({
    required String assignmentId,
    required String revisionId,
  }) => throw UnimplementedError();

  @override
  Future<CoachProgramRevisionAcceptanceResult> accept({
    required String assignmentId,
    required String revisionId,
  }) =>
      throw UnimplementedError();
}

class _AcceptanceService implements CoachProgramRevisionAcceptanceService {
  bool accepted = false;
  int acceptCalls = 0;

  @override
  Never get client => throw UnimplementedError();

  @override
  Future<CoachProgramRevisionState> loadState(String assignmentId) =>
      throw UnimplementedError();

  @override
  Future<ClientProgramRevisionPage> loadPage(
    ClientProgramRevisionPageQuery query,
  ) =>
      throw UnimplementedError();

  @override
  Future<AcceptedProgramRevisionSnapshot> loadAcceptedRevision({
    required String assignmentId,
    required String revisionId,
  }) => throw UnimplementedError();

  @override
  Future<CoachProgramRevisionAcceptanceResult> accept({
    required String assignmentId,
    required String revisionId,
  }) async {
    acceptCalls++;
    accepted = true;
    return CoachProgramRevisionAcceptanceResult(
      assignmentId: assignmentId,
      revisionId: revisionId,
      revisionNumber: 2,
      acceptedAt: DateTime(2026, 10, 6, 22, 30),
      alreadyAccepted: false,
      currentAssignmentVersion: 1,
    );
  }
}

CoachProgramRevisionState _state() => CoachProgramRevisionState(
      assignmentId: 'program',
      relationshipId: 'rel',
      assignmentStatus: AssignedProgramStatus.accepted,
      currentAssignmentVersion: 1,
      acceptedRevisionId: 'rev-1',
      acceptedRevisionNumber: 1,
      acceptedAt: DateTime(2026, 10, 5),
      latestRevisionId: 'rev-2',
      latestRevisionNumber: 2,
      latestSourceKind: 'coach_revision',
      latestRecordedAt: DateTime(2026, 10, 6),
      latestAuthoredAt: DateTime(2026, 10, 6),
      revisionAccessActive: true,
      hasPendingRevision: true,
      canAcceptLatest: true,
    );

ClientProgramRevisionPage _page({
  required bool accepted,
  String? routineId,
}) {
  if (routineId != null) {
    return ClientProgramRevisionPage(
      assignmentId: 'program',
      relationshipId: 'rel',
      revisionId: 'rev-2',
      revisionNumber: 2,
      previousRevisionId: 'rev-1',
      sourceKind: 'coach_revision',
      observedAssignmentVersion: 1,
      name: 'Plan fuerza',
      durationWeeks: 10,
      trainingWeekdays: const {1, 3, 5},
      startsOn: DateTime(2026, 10, 12),
      recordedAt: DateTime(2026, 10, 6),
      authoredAt: DateTime(2026, 10, 6),
      acceptedAt: accepted ? DateTime(2026, 10, 6, 22, 30) : null,
      isAccepted: accepted,
      canAccept: false,
      routineName: 'Upper A',
      totalCount: 1,
      exercises: [
        AssignedExerciseSnapshot.fromJson({
          'id': 'exercise',
          'position': 0,
          'name': 'Remo unilateral',
          'target_sets': 3,
          'target_reps_min': 8,
          'target_reps_max': 12,
          'rest_seconds': 150,
          'warmup_sets': 1,
          'approach_sets': 1,
          'warmup_rest_seconds': 45,
          'approach_rest_seconds': 75,
          'unilateral': true,
          'unilateral_target': 'back',
          'preparation_unilateral': false,
          'unilateral_side_rest_seconds': 0,
          'preferred_unilateral_start_side': 'right',
        }),
      ],
    );
  }

  return ClientProgramRevisionPage(
    assignmentId: 'program',
    relationshipId: 'rel',
    revisionId: 'rev-2',
    revisionNumber: 2,
    previousRevisionId: 'rev-1',
    sourceKind: 'coach_revision',
    observedAssignmentVersion: 1,
    name: 'Plan fuerza',
    durationWeeks: 10,
    trainingWeekdays: const {1, 3, 5},
    startsOn: DateTime(2026, 10, 12),
    recordedAt: DateTime(2026, 10, 6),
    authoredAt: DateTime(2026, 10, 6),
    acceptedAt: accepted ? DateTime(2026, 10, 6, 22, 30) : null,
    isAccepted: accepted,
    canAccept: !accepted,
    totalCount: 1,
    routines: const [
      ClientProgramRevisionRoutineSummary(
        id: 'routine',
        name: 'Upper A',
        position: 0,
      ),
    ],
  );
}

void main() {
  test('client revision service validates state/page/accept contracts', () async {
    final requests = <http.Request>[];
    String? corrupt;
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final params = jsonDecode(request.body) as Map<String, dynamic>;

        if (request.url.path.endsWith('stk_get_my_program_revision_state')) {
          return http.Response(
            jsonEncode({
              'assignment_id':
                  corrupt == 'state_scope' ? 'other' : 'program',
              'relationship_id': 'rel',
              'assignment_status': 'accepted',
              'current_assignment_version': 1,
              'accepted_revision_id': 'rev-1',
              'accepted_revision_number': 1,
              'accepted_at': '2026-10-05T10:00:00Z',
              'latest_revision_id': 'rev-2',
              'latest_revision_number': 2,
              'latest_source_kind': 'coach_revision',
              'latest_recorded_at': '2026-10-06T12:00:00Z',
              'latest_authored_at': '2026-10-06T11:00:00Z',
              'revision_access_active': true,
              'has_pending_revision': true,
              'can_accept_latest': true,
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.endsWith('stk_accept_program_revision')) {
          return http.Response(
            jsonEncode({
              'assignment_id': 'program',
              'revision_id': 'rev-2',
              'revision_number': 2,
              'accepted_at': '2026-10-06T12:30:00Z',
              'already_accepted': false,
              'current_assignment_version': 1,
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
            'observed_assignment_version': 1,
            'name': 'Plan fuerza',
            'notes': 'Program notes',
            'duration_weeks': 10,
            'training_weekdays': [1, 3, 5],
            'starts_on': '2026-10-12',
            'recorded_at': '2026-10-06T12:00:00Z',
            'authored_at': '2026-10-06T11:00:00Z',
            'accepted_at': null,
            'is_accepted': false,
            'can_accept': true,
            'routine': routineId == null
                ? null
                : {
                    'id': 'routine',
                    'name': 'Upper A',
                    'position': 0,
                    'notes': 'Routine notes',
                  },
            'items': [
              if (routineId == null)
                {
                  'id': 'routine',
                  'name': 'Upper A',
                  'position': 0,
                  'notes': 'Routine notes',
                }
              else
                {
                  'id': 'exercise',
                  'name': 'Remo unilateral',
                  'position': 0,
                  'muscle_group': 'Espalda',
                  'equipment': 'Mancuerna',
                  'target_sets': 3,
                  'target_reps_min': 8,
                  'target_reps_max': 12,
                  'rest_seconds': 150,
                  'warmup_sets': 1,
                  'approach_sets': 1,
                  'warmup_rest_seconds': 45,
                  'approach_rest_seconds': 75,
                  'unilateral': true,
                  'unilateral_target': 'back',
                  'preparation_unilateral': false,
                  'unilateral_side_rest_seconds': 0,
                  'preferred_unilateral_start_side': 'right',
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
    final service = CoachProgramRevisionAcceptanceService(client);

    final state = await service.loadState('program');
    expect(state.hasPendingRevision, isTrue);
    expect(state.acceptedRevisionNumber, 1);
    expect(
      jsonDecode(requests.last.body),
      {'p_assignment_id': 'program'},
    );

    final page = await service.loadPage((
      assignmentId: 'program',
      revisionId: 'rev-2',
      routineId: null,
      offset: 0,
    ));
    expect(page.canAccept, isTrue);
    expect(page.routines.single.name, 'Upper A');

    final routine = await service.loadPage((
      assignmentId: 'program',
      revisionId: 'rev-2',
      routineId: 'routine',
      offset: 0,
    ));
    final exercise = routine.exercises.single;
    expect(exercise.warmupRestSeconds, 45);
    expect(exercise.preparationUnilateral, isFalse);
    expect(exercise.unilateralSideRestSeconds, 0);

    final accepted = await service.accept(
      assignmentId: 'program',
      revisionId: 'rev-2',
    );
    expect(accepted.revisionNumber, 2);
    expect(accepted.alreadyAccepted, isFalse);
    expect(
      jsonDecode(requests.last.body),
      {
        'p_assignment_id': 'program',
        'p_revision_id': 'rev-2',
      },
    );

    corrupt = 'state_scope';
    await expectLater(
      service.loadState('program'),
      throwsFormatException,
    );
  });

  test('accepted revision loader assembles all paginated routines', () async {
    final rootOffsets = <int>[];
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      httpClient: MockClient((request) async {
        final params = jsonDecode(request.body) as Map<String, dynamic>;
        final routineId = params['p_revision_routine_id'] as String?;
        final offset = params['p_offset'] as int;

        if (routineId == null) {
          rootOffsets.add(offset);
        }

        final items = routineId == null
            ? [
                for (
                  var index = offset;
                  index < 26 && index < offset + 25;
                  index++
                )
                  {
                    'id': 'routine-$index',
                    'name': 'Routine $index',
                    'position': index,
                    'notes': 'Routine note $index',
                  },
              ]
            : [
                {
                  'id': 'exercise-$routineId',
                  'name': 'Exercise $routineId',
                  'position': 0,
                  'muscle_group': 'Back',
                  'equipment': 'Cable',
                  'target_sets': 3,
                  'target_reps_min': 8,
                  'target_reps_max': 12,
                  'rest_seconds': 120,
                  'warmup_sets': 1,
                  'approach_sets': 1,
                  'warmup_rest_seconds': 45,
                  'approach_rest_seconds': 60,
                  'unilateral': false,
                  'unilateral_target': 'other',
                  'preparation_unilateral': false,
                  'unilateral_side_rest_seconds': null,
                  'preferred_unilateral_start_side': null,
                  'superset_key': null,
                },
              ];

        return http.Response(
          jsonEncode({
            'assignment_id': 'program',
            'relationship_id': 'rel',
            'revision_id': 'rev-accepted',
            'revision_number': 4,
            'previous_revision_id': 'rev-3',
            'source_kind': 'coach_revision',
            'observed_assignment_version': 1,
            'name': 'Accepted program',
            'notes': 'Program install notes',
            'duration_weeks': 12,
            'training_weekdays': [1, 3, 5],
            'starts_on': '2026-10-20',
            'recorded_at': '2026-10-06T20:00:00Z',
            'authored_at': '2026-10-06T19:00:00Z',
            'accepted_at': '2026-10-06T21:00:00Z',
            'is_accepted': true,
            'can_accept': false,
            'routine': routineId == null
                ? null
                : {
                    'id': routineId,
                    'name': 'Routine ${routineId.split('-').last}',
                    'position': int.parse(routineId.split('-').last),
                    'notes':
                        'Routine note ${routineId.split('-').last}',
                  },
            'items': items,
            'total_count': routineId == null ? 26 : 1,
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final service = CoachProgramRevisionAcceptanceService(client);

    final snapshot = await service.loadAcceptedRevision(
      assignmentId: 'program',
      revisionId: 'rev-accepted',
    );

    expect(rootOffsets, [0, 25]);
    expect(snapshot.revisionNumber, 4);
    expect(snapshot.notes, 'Program install notes');
    expect(snapshot.routines, hasLength(26));
    expect(snapshot.routines.first.notes, 'Routine note 0');
    expect(snapshot.routines.last.notes, 'Routine note 25');
    expect(snapshot.routines.last.exercises, hasLength(1));
  });

  test('sign-out discards pending client revision state', () async {
    final service = _PendingService();
    final container = ProviderContainer(
      overrides: [
        appIdentityProvider.overrideWith(_Identity.new),
        coachProgramRevisionAcceptanceServiceProvider.overrideWithValue(
          service,
        ),
      ],
    );
    addTearDown(container.dispose);

    final provider = coachProgramRevisionStateProvider('program');
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
    expect(await container.read(provider.future), isNull);

    service.pending.complete(_state());
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).value, isNull);
    expect(service.calls, 1);
  });

  testWidgets(
    'client reviews prescription and accepts without installing',
    (tester) async {
      final service = _AcceptanceService();
      final queries = <ClientProgramRevisionPageQuery>[];
      final container = ProviderContainer(
        overrides: [
          appIdentityProvider.overrideWith(_Identity.new),
          coachProgramRevisionAcceptanceServiceProvider.overrideWithValue(
            service,
          ),
          clientProgramRevisionPageProvider.overrideWith(
            (ref, query) async {
              queries.add(query);
              return _page(
                accepted: service.accepted,
                routineId: query.routineId,
              );
            },
          ),
          coachProgramRevisionStateProvider.overrideWith(
            (ref, assignmentId) async => _state(),
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
            home: CoachProgramRevisionReviewPage(
              assignmentId: 'program',
              revisionId: 'rev-2',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aceptar revisión 2'), findsOneWidget);
      expect(
        find.textContaining('No cambia, instala ni activa'),
        findsOneWidget,
      );

      await tester.tap(find.text('Upper A'));
      await tester.pumpAndSettle();
      expect(find.text('Remo unilateral'), findsOneWidget);
      expect(find.textContaining('Calentamiento: 1 · 45s'), findsOneWidget);
      expect(find.textContaining('Preparación bilateral'), findsOneWidget);
      expect(queries.last.routineId, 'routine');

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar revisión 2'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Aceptar revisión'));
      await tester.pumpAndSettle();

      expect(service.acceptCalls, 1);
      expect(find.text('Revisión aceptada'), findsOneWidget);
      expect(
        find.textContaining('Tu programa local todavía no cambió'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
