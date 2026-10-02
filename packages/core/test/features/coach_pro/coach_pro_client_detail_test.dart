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

CoachProClientSummary _summary({bool permission = true, String status = 'active'}) =>
    CoachProClientSummary.fromJson({
      'relationship_id': 'rel', 'client_user_id': 'client',
      'relationship_status': status, 'permissions': {'view_checkins': permission},
    });

class _Service implements CoachProClientDetailService {
  int summaries = 0;
  final offsets = <int>[];
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
}

void main() {
  const summaryQuery = (relationshipId: 'rel', checkins: false, offset: 0);
  const checkinQuery = (relationshipId: 'rel', checkins: true, offset: 25);
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
