import 'dart:async';

import 'package:core/features/coach_pro/domain/coach_pro_dashboard_query.dart';

import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/features/coach_pro/data/coach_pro_dashboard_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final coachProDashboardServiceProvider = Provider<CoachProDashboardService>(
  (ref) => CoachProDashboardService(Supabase.instance.client),
);

enum CoachProDashboardStatus { accountRequired, loading, ready, error }

/// A single page in memory. No persisted roster or client-side access grant.
class CoachProDashboardState {
  static const pageSize = 25;
  final String search;
  final int offset;
  final CoachProClientStatusFilter clientStatus;
  final bool onlyNeedsReview;
  final CoachProClientSort sort;
  final List<CoachProClientSummary> clients;
  final int? totalCount;
  final CoachProDashboardStatus status;
  final String? message;

  const CoachProDashboardState({
    this.search = '',
    this.offset = 0,
    this.clientStatus = CoachProClientStatusFilter.all,
    this.onlyNeedsReview = false,
    this.sort = CoachProClientSort.review,
    this.clients = const [],
    this.totalCount,
    this.status = CoachProDashboardStatus.accountRequired,
    this.message,
  });

  bool get hasNext =>
      status == CoachProDashboardStatus.ready &&
      clients.isNotEmpty &&
      offset + pageSize < (totalCount ?? 0) &&
      offset + pageSize <= 10000;
  bool get hasPrevious =>
      status != CoachProDashboardStatus.loading && offset > 0;
}

final coachProDashboardProvider = NotifierProvider.autoDispose<
    CoachProDashboardNotifier, CoachProDashboardState>(
  CoachProDashboardNotifier.new,
);

class CoachProDashboardNotifier extends Notifier<CoachProDashboardState> {
  int _generation = 0;

  @override
  CoachProDashboardState build() {
    final identity = ref.watch(appIdentityProvider.select(
      (value) => (value.signedIn, value.userId),
    ));
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    if (!identity.$1 || identity.$2 == null) {
      return const CoachProDashboardState();
    }
    final service = ref.watch(coachProDashboardServiceProvider);
    // Build returns an empty loading state before a request can complete.
    scheduleMicrotask(() {
      if (ref.mounted && generation == _generation) {
        unawaited(_load(service, const CoachProDashboardState(), generation));
      }
    });
    return const CoachProDashboardState(status: CoachProDashboardStatus.loading);
  }

  Future<void> search(String value) {
    final normalized = value.trim();
    if (normalized.runes.length > 80) {
      throw ArgumentError.value(value, 'search', 'Maximum 80 characters');
    }
    if (normalized == state.search) return Future.value();
    return _request(normalized, 0);
  }

  Future<void> setFilters({
    CoachProClientStatusFilter? clientStatus,
    bool? onlyNeedsReview,
    CoachProClientSort? sort,
  }) => _request(state.search, 0,
      clientStatus: clientStatus, onlyNeedsReview: onlyNeedsReview, sort: sort);

  Future<void> refresh() => _request(state.search, state.offset);

  Future<void> nextPage() => state.hasNext
      ? _request(state.search, state.offset + CoachProDashboardState.pageSize)
      : Future.value();

  Future<void> previousPage() => state.hasPrevious
      ? _request(state.search, state.offset - CoachProDashboardState.pageSize)
      : Future.value();

  Future<void> _request(String search, int offset, {
    CoachProClientStatusFilter? clientStatus,
    bool? onlyNeedsReview,
    CoachProClientSort? sort,
  }) {
    final identity = ref.read(appIdentityProvider);
    if (!identity.signedIn || identity.userId == null) return Future.value();
    final service = ref.read(coachProDashboardServiceProvider);
    final generation = ++_generation;
    // Clear prior data on refresh, query change and error: permissions can change.
    state = CoachProDashboardState(
      search: search,
      offset: offset,
      clientStatus: clientStatus ?? state.clientStatus,
      onlyNeedsReview: onlyNeedsReview ?? state.onlyNeedsReview,
      sort: sort ?? state.sort,
      status: CoachProDashboardStatus.loading,
    );
    return _load(service, state, generation);
  }

  Future<void> _load(CoachProDashboardService service,
      CoachProDashboardState query, int generation) async {
    try {
      final clients = await service.listClients(
        search: query.search,
        status: query.clientStatus,
        needsReview: query.onlyNeedsReview ? true : null,
        sort: query.sort,
        limit: CoachProDashboardState.pageSize,
        offset: query.offset,
      );
      if (!ref.mounted || generation != _generation) return;
      state = CoachProDashboardState(
        search: query.search,
        clientStatus: query.clientStatus,
        onlyNeedsReview: query.onlyNeedsReview,
        sort: query.sort,
        offset: query.offset,
        clients: List.unmodifiable(clients),
        totalCount: clients.isEmpty
            ? (query.offset == 0 ? 0 : null)
            : clients.first.totalCount,
        status: CoachProDashboardStatus.ready,
      );
    } catch (_) {
      if (!ref.mounted || generation != _generation) return;
      // Never retain protected rows or expose raw backend errors/PII.
      state = CoachProDashboardState(
        search: query.search,
        clientStatus: query.clientStatus,
        onlyNeedsReview: query.onlyNeedsReview,
        sort: query.sort,
        offset: query.offset,
        status: CoachProDashboardStatus.error,
        message: 'No se pudo cargar la cartera. Revisa la conexión y tu acceso '
            'a Coach Pro, y vuelve a intentar.',
      );
    }
  }
}
