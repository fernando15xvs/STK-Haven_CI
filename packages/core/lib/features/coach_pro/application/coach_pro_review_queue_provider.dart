import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/features/coach_pro/application/coach_pro_dashboard_provider.dart';
import 'package:core/features/coach_pro/domain/coach_pro_dashboard_query.dart';
import 'package:core/features/coach_pro/domain/coach_pro_review_reason.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef CoachProReviewQueueQuery = ({String userId, int offset});

class CoachProReviewQueuePage {
  static const pageSize = 25;
  final List<CoachProClientSummary> clients;
  final int? totalCount;

  const CoachProReviewQueuePage({required this.clients, required this.totalCount});

  bool hasMoreAt(int offset) =>
      clients.isNotEmpty && totalCount != null &&
      offset + pageSize < totalCount! && offset + pageSize <= 10000;
}

/// A page-scoped inbox isolated from roster filters. No full-portfolio preload.
final coachProReviewQueueProvider = FutureProvider.autoDispose
    .family<CoachProReviewQueuePage?, CoachProReviewQueueQuery>(
  (ref, query) async {
    final identity = ref.watch(
      appIdentityProvider.select((value) => (value.signedIn, value.userId)),
    );
    if (!identity.$1 || identity.$2 == null ||
        identity.$2 != query.userId) return null;
    if (query.offset < 0 || query.offset > 10000 ||
        query.offset % CoachProReviewQueuePage.pageSize != 0) {
      throw ArgumentError.value(query.offset, 'offset');
    }
    final clients = await ref.watch(coachProDashboardServiceProvider).listClients(
      limit: CoachProReviewQueuePage.pageSize,
      offset: query.offset,
      status: CoachProClientStatusFilter.active,
      needsReview: true,
      sort: CoachProClientSort.review,
    );
    // Fail closed if a backend regression returns unconsented review data.
    for (final client in clients) {
      if (coachProReviewReason(client) == null) {
        throw const FormatException('Invalid authorized review item');
      }
    }
    if (clients.isNotEmpty) {
      final count = clients.first.totalCount;
      if (count < clients.length || count > 100000 ||
          clients.any((item) => item.totalCount != count)) {
        throw const FormatException('Invalid review page count');
      }
    }
    return CoachProReviewQueuePage(
      clients: List.unmodifiable(clients),
      totalCount: clients.isEmpty
          ? (query.offset == 0 ? 0 : null)
          : clients.first.totalCount,
    );
  },
);
