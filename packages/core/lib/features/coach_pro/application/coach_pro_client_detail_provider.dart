import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/domain/models/coach_relationship.dart';
import 'package:core/features/coach_pro/data/coach_pro_client_detail_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CoachProClientDetailQuery = ({String relationshipId, bool checkins, int offset});

class CoachProClientDetail {
  final CoachProClientSummary summary;
  final CoachProCheckinPage? checkins;
  const CoachProClientDetail(this.summary, {this.checkins});
  bool get canViewCheckins =>
      summary.relationshipStatus == CoachRelationshipStatus.active &&
      summary.permissions.contains(CoachPermission.viewCheckins);
}

final coachProClientDetailServiceProvider = Provider<CoachProClientDetailService>(
  (ref) => CoachProClientDetailService(Supabase.instance.client),
);

/// One relationship and one selected section/page; never a persisted client cache.
final coachProClientDetailProvider = FutureProvider.autoDispose
    .family<CoachProClientDetail?, CoachProClientDetailQuery>((ref, query) async {
  final identity = ref.watch(appIdentityProvider.select(
    (value) => (value.signedIn, value.userId),
  ));
  if (!identity.$1 || identity.$2 == null) return null;
  final service = ref.watch(coachProClientDetailServiceProvider);
  final summary = await service.getSummary(query.relationshipId);
  if (!ref.mounted || summary == null) return null;
  final detail = CoachProClientDetail(summary);
  if (!query.checkins || !detail.canViewCheckins) return detail;
  final page = await service.listCheckins(query.relationshipId, offset: query.offset);
  // Errors propagate for the entire view; never retain a stale protected summary.
  return CoachProClientDetail(summary, checkins: page);
});
