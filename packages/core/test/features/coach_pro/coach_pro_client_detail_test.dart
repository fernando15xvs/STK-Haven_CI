import 'package:core/domain/models/coach_client_progress.dart';
import 'package:core/domain/models/coach_exercise_progress.dart';
import 'package:core/domain/models/nutrition_guidance.dart';
import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/features/coach_pro/domain/coach_pro_task_summary.dart';
import 'dart:async';
import 'dart:convert';

import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/coach_checkin.dart';
import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/features/coach_pro/application/coach_pro_client_detail_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_client_detail_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Identity extends AppIdentityNotifier {
  @override
  AppIdentityState build() => const AppIdentityState(
    sessionKind: AppSessionKind.permanent, userId: 'coach',
  );
  void signOutForTest() => state = const AppIdentityState();
}

CoachProClientSummary _summary({bool permission = true, String status = 'active', bool programs = false, bool tasks = false}) =>
    CoachProClientSummary.fromJson({
      'relationship_id': 'rel', 'client_user_id': 'client',
      'relationship_status': status, 'permissions': {'view_checkins': permission, 'assign_programs': programs, 'assign_tasks': tasks},
    });

class _Service implements CoachProClientDetailService {
  int summaries = 0;
  final offsets = <int>[];
  final programOffsets = <int>[];
  final taskOffsets = <int>[];
  final workoutOffsets = <int>[];
  final exerciseProgressOffsets = <int>[];
  int progressReads = 0;
  final nutritionOffsets = <int>[];
  @override
  Future<CoachProSectionPage<NutritionGuidanceSummary>> listNutrition(
      String relationshipId, String clientUserId, {int offset = 0}) async {
    expect(clientUserId, 'client'); nutritionOffsets.add(offset);
    return const CoachProSectionPage(totalCount: 0);
  }
  Completer<CoachClientProgress?>? progressPending;
  @override
  Future<CoachClientProgress?> getProgress(String relationshipId, String clientUserId) async {
    expect(clientUserId, 'client'); progressReads++;
    if (fail) throw StateError('sensitive');
    return progressPending == null ? null : await progressPending!.future;
  }
  @override
  Future<CoachProSectionPage<CoachExerciseProgressSummary>>
      listExerciseProgress(
    String relationshipId,
    String clientUserId, {
    int limit = 25,
    int offset = 0,
  }) async {
    expect(clientUserId, 'client');
    exerciseProgressOffsets.add(offset);
    if (fail) throw StateError('sensitive');
    return const CoachProSectionPage(totalCount: 0);
  }

  @override
  Future<CoachProSectionPage<CoachSharedWorkoutSummary>> listWorkouts(
      String relationshipId, String clientUserId, {int limit = 25, int offset = 0}) async {
    expect(clientUserId, 'client');
    workoutOffsets.add(offset);
    if (fail) throw StateError('sensitive');
    return const CoachProSectionPage(totalCount: 0);
  }
  CoachProClientSummary? summary = _summary();
  Completer<CoachProClientSummary?>? pending;
  bool fail = false;
  @override
  Never get client => throw UnimplementedError();
  @override
  Future<CoachProClientSummary?> getSummary(String relationshipId) async {
    summaries++;
    return pending == null ? summary : await pending!.future;
  }
  @override
  Future<CoachProCheckinPage> listCheckins(String relationshipId,
      {int limit = 25, int offset = 0}) async {
    offsets.add(offset);
    if (fail) throw StateError('sensitive');
    return const CoachProCheckinPage(totalCount: 0);
  }
  @override
  Future<CoachProSectionPage<CoachProgramAssignmentSummary>> listPrograms(
      String relationshipId, {int limit = 25, int offset = 0}) async {
    programOffsets.add(offset);
    if (fail) throw StateError('sensitive');
    return const CoachProSectionPage(totalCount: 0);
  }
  @override
  Future<CoachProSectionPage<CoachProTaskSummary>> listTasks(
      String relationshipId, {int limit = 25, int offset = 0}) async {
    taskOffsets.add(offset);
    if (fail) throw StateError('sensitive');
    return const CoachProSectionPage(totalCount: 0);
  }

}

void main() {
  const summaryQuery = (relationshipId: 'rel', section: CoachProClientSection.summary, offset: 0);
  const checkinQuery = (relationshipId: 'rel', section: CoachProClientSection.checkins, offset: 25);
  late _Service service;
  late ProviderContainer container;
  setUp(() {
    service = _Service();
    container = ProviderContainer(overrides: [
      appIdentityProvider.overrideWith(_Identity.new),
      coachProClientDetailServiceProvider.overrideWithValue(service),
    ]);
  });
  tearDown(() => container.dispose());
  test('nutrition list is lazy and independent from progress consent', () async {
    service.summary = CoachProClientSummary.fromJson({'relationship_id': 'rel', 'client_user_id': 'client',
      'relationship_status': 'active', 'permissions': {'view_nutrition': true}});
    await container.read(coachProClientDetailProvider(summaryQuery).future);
    expect(service.nutritionOffsets, isEmpty);
    final provider = coachProClientDetailProvider(
      (relationshipId: 'rel', section: CoachProClientSection.nutrition, offset: 25));
    container.listen(provider, (_, _) {});
    expect((await container.read(provider.future))!.nutrition, isNotNull);
    expect(service.nutritionOffsets, [25]); expect(service.progressReads, 0);
    service.summary = CoachProClientSummary.fromJson({'relationship_id': 'rel', 'client_user_id': 'client',
      'relationship_status': 'active', 'permissions': {'view_progress': true}});
    container.invalidate(provider);
    expect((await container.read(provider.future))!.nutrition, isNull);
    expect(service.nutritionOffsets, [25]);
  });

  test('progress is lazy, requires its own consent and stops after revocation', () async {
    service.summary = CoachProClientSummary.fromJson({
      'relationship_id': 'rel', 'client_user_id': 'client', 'relationship_status': 'active',
      'permissions': {'view_progress': true},
    });
    await container.read(coachProClientDetailProvider(summaryQuery).future);
    expect(service.progressReads, 0);
    final provider = coachProClientDetailProvider(
      (relationshipId: 'rel', section: CoachProClientSection.progress, offset: 0));
    container.listen(provider, (_, _) {});
    final detail = await container.read(provider.future);
    expect(detail!.canViewProgress, isTrue); expect(detail.progress, isNull);
    expect(service.progressReads, 1); expect(service.workoutOffsets, isEmpty);
    service.summary = CoachProClientSummary.fromJson({
      'relationship_id': 'rel', 'client_user_id': 'client', 'relationship_status': 'active',
      'permissions': {'view_workouts': true},
    });
    container.invalidate(provider);
    expect((await container.read(provider.future))!.canViewProgress, isFalse);
    expect(service.progressReads, 1);
  });
  test('progress response after sign-out is discarded', () async {
    service.summary = CoachProClientSummary.fromJson({
      'relationship_id': 'rel', 'client_user_id': 'client', 'relationship_status': 'active',
      'permissions': {'view_progress': true},
    });
    service.progressPending = Completer<CoachClientProgress?>();
    final provider = coachProClientDetailProvider(
      (relationshipId: 'rel', section: CoachProClientSection.progress, offset: 0));
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero); expect(service.progressReads, 1);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
    expect(await container.read(provider.future), isNull);
    service.progressPending!.complete(CoachClientProgress(workouts7d: 1, workouts30d: 1,
      trainingMinutes7d: 10, completedWorkingSets7d: 1, volume7d: 0, generatedAt: DateTime(2026)));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).value, isNull);
  });
  test('progress parser preserves missing snapshot and genuine zero, rejects incomplete values and wrong scope', () async {
    final requests = <http.Request>[];
    String? corrupt; bool missing = false;
    final client = SupabaseClient('https://example.test', 'test-key', httpClient: MockClient((request) async {
      requests.add(request);
      final snapshot = <String, dynamic>{
        'workouts_7d': 0,
        'workouts_30d': 0,
        'training_minutes_7d': 0,
        'completed_working_sets_7d': 0,
        'volume_7d': 0,
        'average_rir_7d': null,
        'last_workout_at': null,
        'generated_at': '2026-09-01T00:00:00Z',
        'trend_baseline_available': true,
        'workouts_previous_7d': 2,
        'training_minutes_previous_7d': 90,
        'completed_working_sets_previous_7d': 20,
        'volume_previous_7d': 5000,
      };
      if (corrupt == 'minutes') snapshot.remove('training_minutes_7d');
      if (corrupt == 'date') snapshot['generated_at'] = null;
      if (corrupt == 'last') snapshot['last_workout_at'] = 'invalid';
      if (corrupt == 'rir') snapshot['average_rir_7d'] = 11;
      if (corrupt == 'count') snapshot['workouts_7d'] = 1;
      final adherence = {
        'assignment_id': 'assignment',
        'assignment_name': 'Plan fuerza',
        'starts_on': '2026-08-01',
        'ends_on': '2026-10-31',
        'scheduled_sessions_7d': 3,
        'completed_sessions_7d': 0,
        'percent_7d': 0,
        'scheduled_sessions_30d': 13,
        'completed_sessions_30d': 0,
        'percent_30d': 0,
      };
      if (corrupt == 'baseline') snapshot['trend_baseline_available'] = null;
      if (corrupt == 'previous') snapshot['workouts_previous_7d'] = -1;
      if (corrupt == 'adherence') adherence['percent_7d'] = 101;
      return http.Response(jsonEncode({'relationship_id': corrupt == 'relationship' ? 'other' : 'rel',
        'client_user_id': corrupt == 'client' ? 'other' : 'client',
        'snapshot': missing ? null : snapshot,
        'adherence': missing ? null : adherence}),
        200, request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose); final live = CoachProClientDetailService(client);
    final value = await live.getProgress('rel', 'client');
    expect(requests.single.url.path, '/rest/v1/rpc/stk_get_coach_pro_client_progress');
    expect(jsonDecode(requests.single.body), {'p_relationship_id': 'rel'});
    expect(value!.workouts7d, 0); expect(value.trainingMinutes7d, 0);
    expect(value.averageRir7d, isNull); expect(value.lastWorkoutAt, isNull);
    expect(value.generatedAt, DateTime.utc(2026, 9, 1));
    expect(value.trendBaselineAvailable, isTrue);
    expect(value.workoutsPrevious7d, 2);
    expect(value.frequencyAdherence?.assignmentName, 'Plan fuerza');
    expect(value.frequencyAdherence?.percent7d, 0);
    expect(value.workoutsVisible, isFalse); expect(value.recentWorkouts, isEmpty);
    for (final key in ['minutes', 'date', 'last', 'rir', 'count', 'baseline',
      'previous', 'adherence', 'relationship', 'client']) {
      corrupt = key; await expectLater(live.getProgress('rel', 'client'), throwsFormatException);
    }
    corrupt = null; missing = true; expect(await live.getProgress('rel', 'client'), isNull);
  });

  test(
    'exercise progress is lazy and requires both progress and workout consent',
    () async {
      service.summary = CoachProClientSummary.fromJson({
        'relationship_id': 'rel',
        'client_user_id': 'client',
        'relationship_status': 'active',
        'permissions': {
          'view_progress': true,
          'view_workouts': false,
        },
      });
      final provider = coachProClientDetailProvider((
        relationshipId: 'rel',
        section: CoachProClientSection.exerciseProgress,
        offset: 25,
      ));
      container.listen(provider, (_, _) {});
      expect((await container.read(provider.future))!.exerciseProgress, isNull);
      expect(service.exerciseProgressOffsets, isEmpty);

      service.summary = CoachProClientSummary.fromJson({
        'relationship_id': 'rel',
        'client_user_id': 'client',
        'relationship_status': 'active',
        'permissions': {
          'view_progress': true,
          'view_workouts': true,
        },
      });
      container.invalidate(provider);
      expect(
        (await container.read(provider.future))!.exerciseProgress,
        isNotNull,
      );
      expect(service.exerciseProgressOffsets, [25]);

      service.summary = CoachProClientSummary.fromJson({
        'relationship_id': 'rel',
        'client_user_id': 'client',
        'relationship_status': 'active',
        'permissions': {
          'view_progress': false,
          'view_workouts': true,
        },
      });
      container.invalidate(provider);
      expect((await container.read(provider.future))!.exerciseProgress, isNull);
      expect(service.exerciseProgressOffsets, [25]);
    },
  );

  test('workouts are lazy, independent of progress, and revocation stops subsequent queries', () async {
    service.summary = CoachProClientSummary.fromJson({
      'relationship_id': 'rel', 'client_user_id': 'client', 'relationship_status': 'active',
      'permissions': {'view_workouts': true, 'view_progress': false},
    });
    await container.read(coachProClientDetailProvider(summaryQuery).future);
    expect(service.workoutOffsets, isEmpty);
    final provider = coachProClientDetailProvider(
      (relationshipId: 'rel', section: CoachProClientSection.workouts, offset: 25));
    container.listen(provider, (_, _) {});
    expect((await container.read(provider.future))!.workouts, isNotNull);
    expect(service.workoutOffsets, [25]);
    expect(service.offsets, isEmpty); expect(service.programOffsets, isEmpty); expect(service.taskOffsets, isEmpty);
    service.summary = _summary(programs: true, tasks: true);
    container.invalidate(provider);
    expect((await container.read(provider.future))!.workouts, isNull);
    expect(service.workoutOffsets, [25]);
  });
  test('paused workouts are hidden and authorized query errors fail the whole detail', () async {
    final provider = coachProClientDetailProvider(
      (relationshipId: 'rel', section: CoachProClientSection.workouts, offset: 0));
    service.summary = CoachProClientSummary.fromJson({
      'relationship_id': 'rel', 'client_user_id': 'client', 'relationship_status': 'paused',
      'permissions': {'view_workouts': true},
    });
    container.listen(provider, (_, _) {});
    expect((await container.read(provider.future))!.workouts, isNull);
    expect(service.workoutOffsets, isEmpty);
    service.summary = CoachProClientSummary.fromJson({
      'relationship_id': 'rel', 'client_user_id': 'client', 'relationship_status': 'active',
      'permissions': {'view_workouts': true},
    });
    service.fail = true; container.invalidate(provider);
    await expectLater(container.read(provider.future), throwsStateError);
  });
  test(
    'exercise progress RPC validates scope and aggregate-only rows',
    () async {
      String? corrupt;
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.test',
        'test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          final row = <String, dynamic>{
            'client_user_id': corrupt == 'client' ? 'other' : 'client',
            'exercise_id': 'bench',
            'exercise_name': 'Press banca',
            'muscle_group': 'Pecho',
            'last_performed_at': '2026-10-06T12:00:00Z',
            'generated_at': '2026-10-07T12:00:00Z',
            'sessions_30d': 5,
            'working_sets_30d': 20,
            'volume_30d': 12000,
            'average_rir_30d': 2.5,
            'sessions_previous_30d': 4,
            'working_sets_previous_30d': 16,
            'volume_previous_30d': 10000,
            'best_estimated_1rm_30d': 120.0,
            'best_estimated_1rm_previous_30d': 115.0,
            'best_weight': 110.0,
            'best_weight_at': '2026-09-30T12:00:00Z',
            'best_estimated_1rm': 122.0,
            'best_estimated_1rm_at': '2026-10-01T12:00:00Z',
            'best_set_volume': 1000.0,
            'best_set_volume_at': '2026-09-28T12:00:00Z',
          };
          if (corrupt == 'date') {
            row['last_performed_at'] = 'invalid';
          }
          if (corrupt == 'count') row['sessions_30d'] = -1;
          if (corrupt == 'rir') row['average_rir_30d'] = 11;
          if (corrupt == 'pr-date') row['best_weight_at'] = null;
          return http.Response(
            jsonEncode({
              'relationship_id':
                  corrupt == 'relationship' ? 'other' : 'rel',
              'client_user_id': 'client',
              'total_count': 1,
              'items': [row],
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final live = CoachProClientDetailService(client);

      final page = await live.listExerciseProgress(
        'rel',
        'client',
        offset: 25,
      );
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/stk_list_coach_pro_client_exercise_progress',
      );
      expect(
        jsonDecode(requests.single.body),
        {
          'p_relationship_id': 'rel',
          'p_limit': 25,
          'p_offset': 25,
        },
      );
      expect(page.items.single.exerciseName, 'Press banca');
      expect(page.items.single.volumeDelta30d, 2000);
      expect(page.items.single.estimated1RmDelta30d, 5);
      expect(page.items.single.bestWeight, 110);
      expect(
        page.items.single.toSyncJson().toString(),
        isNot(contains('notes')),
      );

      for (final key in [
        'client',
        'date',
        'count',
        'rir',
        'pr-date',
        'relationship',
      ]) {
        corrupt = key;
        await expectLater(
          live.listExerciseProgress('rel', 'client'),
          throwsFormatException,
        );
      }
    },
  );

  test('workout RPC validates client scope, exact counts and null RIR without inventing data', () async {
    String? corrupt; bool empty = false;
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.test', 'test-key', httpClient: MockClient((request) async {
      requests.add(request);
      final row = <String, dynamic>{'client_user_id': 'client', 'workout_id': 'w',
        'started_at': '2026-10-01T00:00:00Z', 'routine_name': 'Fuerza', 'duration_seconds': 0,
        'planned_working_sets': 0, 'completed_working_sets': 0, 'completion_percent': 0,
        'volume': 0, 'average_rir': null};
      if (corrupt == 'client') row['client_user_id'] = 'other';
      if (corrupt == 'date') row['started_at'] = null;
      if (corrupt == 'duration') row['duration_seconds'] = null;
      if (corrupt == 'sets') row['completed_working_sets'] = 1;
      if (corrupt == 'rir') row['average_rir'] = 11;
      return http.Response(jsonEncode({'relationship_id': corrupt == 'relationship' ? 'other' : 'rel',
        'client_user_id': 'client', 'total_count': 27, 'items': empty ? [] : [row]}),200,
        request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final live = CoachProClientDetailService(client);
    final page = await live.listWorkouts('rel', 'client', offset: 25);
    expect(requests.single.url.path, '/rest/v1/rpc/stk_list_coach_pro_client_workouts');
    expect(jsonDecode(requests.single.body), {'p_relationship_id': 'rel', 'p_limit': 25, 'p_offset': 25});
    expect(page.items.single.averageRir, isNull); expect(page.items.single.volume, 0);
    expect(() => page.items.clear(), throwsUnsupportedError);
    for (final key in ['client', 'date', 'duration', 'sets', 'rir', 'relationship']) {
      corrupt = key; await expectLater(live.listWorkouts('rel', 'client'), throwsFormatException);
    }
    corrupt = null; empty = true;
    final last = await live.listWorkouts('rel', 'client', offset: 50);
    expect(last.items, isEmpty); expect(last.totalCount, 27);
  });

  test('summary is targeted; check-in section loads exactly one selected page', () async {
    container.listen(coachProClientDetailProvider(summaryQuery), (_, _) {});
    await container.read(coachProClientDetailProvider(summaryQuery).future);
    expect(service.summaries, 1);
    expect(service.offsets, isEmpty);
    container.listen(coachProClientDetailProvider(checkinQuery), (_, _) {});
    await container.read(coachProClientDetailProvider(checkinQuery).future);
    expect(service.offsets, [25]);
    expect(service.summaries, 2);
  });

  for (final status in ['active', 'paused']) {
    test('$status without effective permission never requests protected section', () async {
      service.summary = _summary(permission: status == 'paused', status: status);
      container.listen(coachProClientDetailProvider(checkinQuery), (_, _) {});
      final value = await container.read(coachProClientDetailProvider(checkinQuery).future);
      expect(value!.canViewCheckins, isFalse);
      expect(service.offsets, isEmpty);
    });
  }

  test('refresh revocation removes a previously authorized section', () async {
    final provider = coachProClientDetailProvider(checkinQuery);
    container.listen(provider, (_, _) {});
    expect((await container.read(provider.future))!.checkins, isNotNull);
    service.summary = null;
    container.invalidate(provider);
    expect(await container.read(provider.future), isNull);
    expect(service.offsets, [25]);
  });

  test('failed section read fails entire detail instead of returning stale summary', () async {
    service.fail = true;
    final provider = coachProClientDetailProvider(checkinQuery);
    container.listen(provider, (_, _) {});
    await expectLater(container.read(provider.future), throwsStateError);
    expect(container.read(provider).hasError, isTrue);
  });

  test('sign-out during lookup discards late data and prevents section request', () async {
    service.pending = Completer<CoachProClientSummary?>();
    final provider = coachProClientDetailProvider(checkinQuery);
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    (container.read(appIdentityProvider.notifier) as _Identity).signOutForTest();
    expect(await container.read(provider.future), isNull);
    service.pending!.complete(_summary());
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).value, isNull);
    expect(service.offsets, isEmpty);
  });

  for (final section in [CoachProClientSection.programs, CoachProClientSection.tasks]) {
    test('$section loads only selected page and permission revocation stops reload', () async {
      service.summary = _summary(programs: section == CoachProClientSection.programs,
        tasks: section == CoachProClientSection.tasks);
      final provider = coachProClientDetailProvider(
        (relationshipId: 'rel', section: section, offset: 25));
      container.listen(provider, (_, _) {});
      final value = await container.read(provider.future);
      expect(value, isNotNull);
      expect(service.offsets, isEmpty);
      expect(service.programOffsets, section == CoachProClientSection.programs ? [25] : isEmpty);
      expect(service.taskOffsets, section == CoachProClientSection.tasks ? [25] : isEmpty);
      service.summary = _summary(programs: section != CoachProClientSection.programs,
        tasks: section != CoachProClientSection.tasks);
      container.invalidate(provider);
      final denied = await container.read(provider.future);
      expect(denied!.programs, isNull);
      expect(denied.tasks, isNull);
      expect(service.programOffsets.length + service.taskOffsets.length, 1);
    });
    test('$section paused relationships cannot load stored permissions', () async {
      service.summary = _summary(status: 'paused', programs: true, tasks: true);
      final provider = coachProClientDetailProvider(
        (relationshipId: 'rel', section: section, offset: 0));
      container.listen(provider, (_, _) {});
      await container.read(provider.future);
      expect(service.programOffsets, isEmpty);
      expect(service.taskOffsets, isEmpty);
    });
    test('$section error does not return a partial protected detail', () async {
      service.summary = _summary(programs: true, tasks: true);
      service.fail = true;
      final provider = coachProClientDetailProvider(
        (relationshipId: 'rel', section: section, offset: 0));
      container.listen(provider, (_, _) {});
      await expectLater(container.read(provider.future), throwsStateError);
      expect(container.read(provider).hasError, isTrue);
    });
  }

  for (final programs in [true, false]) {
    test('${programs ? 'program' : 'task'} RPC sends bounded query and validates relationship', () async {
      final requests = <http.Request>[];
      bool bad = false;
      bool empty = false;
      final client = SupabaseClient('https://example.test', 'test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(empty ? [] : [{
            'id': 'row', 'relationship_id': bad ? 'other' : 'rel',
            'coach_user_id': 'coach', 'client_user_id': 'client',
            'name': 'Programa', 'title': 'Tarea', 'category': 'General',
            'duration_weeks': 8, 'training_weekdays': [1, 3], 'version': 2,
            'status': programs ? 'accepted' : 'active',
            'starts_on': '2026-10-01', 'created_at': '2026-10-01T00:00:00Z',
            'updated_at': '2026-10-02T00:00:00Z', 'total_count': 27,
          }]), 200, request: request, headers: {'content-type': 'application/json'});
        }));
      addTearDown(client.dispose);
      final live = CoachProClientDetailService(client);
      Future<CoachProSectionPage<dynamic>> load() async => programs
          ? await live.listPrograms('rel', offset: 25)
          : await live.listTasks('rel', offset: 25);
      final page = await load();
      expect(page.totalCount, 27);
      expect(page.items, hasLength(1));
      expect(requests.single.url.path,
        '/rest/v1/rpc/stk_list_coach_pro_client_${programs ? 'programs' : 'tasks'}');
      expect(jsonDecode(requests.single.body), {
        'p_relationship_id': 'rel', 'p_limit': 25, 'p_offset': 25,
      });
      bad = true;
      await expectLater(load(), throwsFormatException);
      empty = true;
      expect((await load()).totalCount, isNull);
    });
  }

  test('service uses targeted RPCs and rejects a mismatched relationship payload', () async {
    final requests = <http.Request>[];
    bool bad = false;
    final client = SupabaseClient('https://example.test', 'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final summary = request.url.path.endsWith('stk_get_coach_pro_client');
        return http.Response(jsonEncode([summary ? {
          'relationship_id': 'rel', 'client_user_id': 'client',
          'relationship_status': 'active', 'permissions': <String, bool>{},
        } : {
          'id': 'checkin', 'relationship_id': bad ? 'other' : 'rel',
          'coach_user_id': 'coach', 'client_user_id': 'client',
          'energy': 3, 'recovery': 4, 'note': 'Shared',
          'created_at': '2026-10-02T00:00:00Z', 'total_count': 26,
        }]), 200, request: request, headers: {'content-type': 'application/json'});
      }));
    addTearDown(client.dispose);
    final live = CoachProClientDetailService(client);
    expect((await live.getSummary('rel'))!.relationshipId, 'rel');
    final page = await live.listCheckins('rel', offset: 25);
    expect(requests, hasLength(2));
    expect(jsonDecode(requests.first.body), {'p_relationship_id': 'rel'});
    expect(jsonDecode(requests.last.body), {
      'p_relationship_id': 'rel', 'p_limit': 25, 'p_offset': 25,
    });
    expect(page.totalCount, 26);
    expect(page.items.single.note, 'Shared');
    expect(() => page.items.add(CoachCheckin.fromJson({})), throwsUnsupportedError);
    bad = true;
    await expectLater(live.listCheckins('rel'), throwsFormatException);
  });
}
