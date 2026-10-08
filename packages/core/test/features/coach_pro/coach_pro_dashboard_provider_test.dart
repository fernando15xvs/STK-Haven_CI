import 'dart:async';

import 'package:core/features/coach_pro/domain/coach_pro_dashboard_query.dart';

import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/domain/models/coach_pro_portfolio_overview.dart';
import 'package:core/features/coach_pro/application/coach_pro_dashboard_provider.dart';
import 'package:core/features/coach_pro/data/coach_pro_dashboard_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Identity extends AppIdentityNotifier {
  @override
  AppIdentityState build() => const AppIdentityState(
        sessionKind: AppSessionKind.permanent,
        userId: 'coach-a',
      );

  void change(String? id) => state = AppIdentityState(
        sessionKind: id == null ? AppSessionKind.none : AppSessionKind.permanent,
        userId: id,
      );

  void anonymous() => state = const AppIdentityState(
        sessionKind: AppSessionKind.anonymous,
        userId: 'anonymous',
      );
}

class _Request {
  final String search;
  final int limit;
  final int offset;
  final CoachProClientStatusFilter status;
  final bool? needsReview;
  final CoachProClientSort sort;
  final result = Completer<List<CoachProClientSummary>>();
  _Request(this.search, this.limit, this.offset, this.status, this.needsReview, this.sort);
}

class _Service implements CoachProDashboardService {
  final requests = <_Request>[];
  @override
  Future<CoachProPortfolioOverview> getPortfolioOverview() =>
      throw UnimplementedError();

  @override
  Never get client => throw UnimplementedError();

  @override
  Future<List<CoachProClientSummary>> listClients({
    String search = '',
    int limit = 25,
    int offset = 0,
    CoachProClientStatusFilter status = CoachProClientStatusFilter.all,
    bool? needsReview,
    CoachProClientSort sort = CoachProClientSort.review,
  }) {
    final request = _Request(search, limit, offset, status, needsReview, sort);
    requests.add(request);
    return request.result.future;
  }
}

CoachProClientSummary _client(String id, {int total = 60}) =>
    CoachProClientSummary.fromJson({
      'relationship_id': id,
      'client_user_id': id,
      'relationship_status': 'active',
      'total_count': total,
    });

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late ProviderContainer container;
  late _Service service;

  setUp(() {
    service = _Service();
    container = ProviderContainer(overrides: [
      appIdentityProvider.overrideWith(_Identity.new),
      coachProDashboardServiceProvider.overrideWithValue(service),
    ]);
    container.listen(coachProDashboardProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  test('loads one page once and uses server offsets without accumulating rows',
      () async {
    await _flush();
    expect(service.requests.single.limit, 25);
    expect(service.requests.single.offset, 0);
    service.requests.single.result.complete([_client('first')]);
    await _flush();
    expect(container.read(coachProDashboardProvider).hasNext, isTrue);
    container.read(coachProDashboardProvider);
    await _flush();
    expect(service.requests, hasLength(1));

    final notifier = container.read(coachProDashboardProvider.notifier);
    final next = notifier.nextPage();
    expect(container.read(coachProDashboardProvider).clients, isEmpty);
    await notifier.nextPage(); // Double tap while loading makes no extra RPC.
    expect(service.requests, hasLength(2));
    expect(service.requests.last.offset, 25);
    service.requests.last.result.complete([_client('second')]);
    await next;
    expect(container.read(coachProDashboardProvider).clients.single.relationshipId,
        'second');
    final previous = notifier.previousPage();
    expect(service.requests.last.offset, 0);
    service.requests.last.result.complete([_client('first')]);
    await previous;
  });

  test('search resets offset and late responses cannot replace a newer search',
      () async {
    await _flush();
    final initial = service.requests.single;
    final notifier = container.read(coachProDashboardProvider.notifier);
    final first = notifier.search(' Alice ');
    final alice = service.requests.last;
    final second = notifier.search('Bob');
    expect(service.requests.last.search, 'Bob');
    expect(service.requests.last.offset, 0);
    service.requests.last.result.complete([_client('bob', total: 1)]);
    await second;
    alice.result.complete([_client('alice')]);
    initial.result.complete([_client('old')]);
    await first;
    await _flush();
    expect(container.read(coachProDashboardProvider).clients.single.relationshipId,
        'bob');
    expect(container.read(coachProDashboardProvider).hasNext, isFalse);
    expect(() => notifier.search(List.filled(81, 'x').join()), throwsArgumentError);
    expect(service.requests, hasLength(3));
  });

  test('filters reset pages, survive search/retry and discard stale results', () async {
    await _flush();
    service.requests.single.result.complete([_client('first')]);
    await _flush();
    final notifier = container.read(coachProDashboardProvider.notifier);
    final next = notifier.nextPage();
    final stale = service.requests.last;
    final changed = notifier.setFilters(
      clientStatus: CoachProClientStatusFilter.active,
      onlyNeedsReview: true,
      sort: CoachProClientSort.recentWorkout,
    );
    final filtered = service.requests.last;
    expect(filtered.offset, 0);
    expect(filtered.status, CoachProClientStatusFilter.active);
    expect(filtered.needsReview, isTrue);
    expect(filtered.sort, CoachProClientSort.recentWorkout);
    expect(container.read(coachProDashboardProvider).clients, isEmpty);
    filtered.result.complete([_client('filtered')]);
    await changed;
    stale.result.complete([_client('stale')]);
    await next;
    expect(container.read(coachProDashboardProvider).clients.single.relationshipId,
        'filtered');
    final searched = notifier.search('Ana');
    expect(service.requests.last.status, CoachProClientStatusFilter.active);
    expect(service.requests.last.sort, CoachProClientSort.recentWorkout);
    expect(service.requests.last.needsReview, isTrue);
    service.requests.last.result.completeError(StateError('offline'));
    await searched;
    final retry = notifier.refresh();
    expect(service.requests.last.search, 'Ana');
    expect(service.requests.last.needsReview, isTrue);
    service.requests.last.result.complete([_client('retry')]);
    await retry;
    final page = notifier.nextPage();
    expect(service.requests.last.offset, 25);
    expect(service.requests.last.sort, CoachProClientSort.recentWorkout);
    service.requests.last.result.complete([]);
    await page;
    final cleared = notifier.setFilters(onlyNeedsReview: false);
    expect(service.requests.last.needsReview, isNull);
    expect(service.requests.last.offset, 0);
    service.requests.last.result.complete([]);
    await cleared;
  });

  test('refresh failure clears protected rows and supports explicit retry',
      () async {
    await _flush();
    service.requests.single.result.complete([_client('private')]);
    await _flush();
    final notifier = container.read(coachProDashboardProvider.notifier);
    final refresh = notifier.refresh();
    expect(container.read(coachProDashboardProvider).clients, isEmpty);
    service.requests.last.result.completeError(StateError('sensitive detail'));
    await refresh;
    final state = container.read(coachProDashboardProvider);
    expect(state.status, CoachProDashboardStatus.error);
    expect(state.clients, isEmpty);
    expect(state.message, isNot(contains('sensitive detail')));
    final retry = notifier.refresh();
    service.requests.last.result.complete([]);
    await retry;
    expect(container.read(coachProDashboardProvider).status,
        CoachProDashboardStatus.ready);
    expect(container.read(coachProDashboardProvider).hasNext, isFalse);
  });

  test('empty later page allows going back without inventing a total count',
      () async {
    await _flush();
    service.requests.single.result.complete([_client('first')]);
    await _flush();
    final next = container.read(coachProDashboardProvider.notifier).nextPage();
    service.requests.last.result.complete([]);
    await next;
    final state = container.read(coachProDashboardProvider);
    expect(state.totalCount, isNull);
    expect(state.hasPrevious, isTrue);
    expect(state.hasNext, isFalse);
    expect(state.clients, isEmpty);
  });

  test('account switch clears data and rejects outstanding prior-account result',
      () async {
    await _flush();
    final old = service.requests.single;
    (container.read(appIdentityProvider.notifier) as _Identity).change('coach-b');
    expect(container.read(coachProDashboardProvider).clients, isEmpty);
    await _flush();
    expect(service.requests, hasLength(2));
    service.requests.last.result.complete([_client('b')]);
    await _flush();
    old.result.complete([_client('a')]);
    await _flush();
    expect(container.read(coachProDashboardProvider).clients.single.relationshipId,
        'b');
  });

  test('sign-out and anonymous sessions cannot retain or request roster data',
      () async {
    await _flush();
    final old = service.requests.single;
    final identity = container.read(appIdentityProvider.notifier) as _Identity;
    identity.change(null);
    expect(container.read(coachProDashboardProvider).status,
        CoachProDashboardStatus.accountRequired);
    old.result.complete([_client('private')]);
    await _flush();
    expect(container.read(coachProDashboardProvider).clients, isEmpty);
    identity.anonymous();
    expect(container.read(coachProDashboardProvider).status,
        CoachProDashboardStatus.accountRequired);
    await container.read(coachProDashboardProvider.notifier).refresh();
    expect(service.requests, hasLength(1));
  });

  test('disposal during a request does not write to a disposed provider', () async {
    await _flush();
    final isolated = container;
    isolated.dispose();
    container = ProviderContainer(); // tearDown disposes this replacement.
    service.requests.single.result.complete([_client('late')]);
    await _flush();
  });
}
