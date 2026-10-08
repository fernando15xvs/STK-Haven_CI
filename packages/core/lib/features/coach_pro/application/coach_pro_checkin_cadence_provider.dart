import 'package:core/features/coach_pro/data/coach_pro_checkin_cadence_service.dart';
import 'package:core/features/coach_pro/domain/coach_pro_checkin_cadence.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CoachProCheckinCadenceQuery = ({
  String userId,
  String relationshipId,
});

final coachProCheckinCadenceServiceProvider =
    Provider<CoachProCheckinCadenceService>(
  (ref) => CoachProCheckinCadenceService(Supabase.instance.client),
);

final coachProCheckinCadenceProvider = FutureProvider.autoDispose
    .family<CoachProCheckinCadence?, CoachProCheckinCadenceQuery>((ref, query) {
  final identity = ref.watch(
    appIdentityProvider.select((s) => (s.signedIn, s.userId)),
  );
  if (!identity.$1 || identity.$2 != query.userId) return null;
  return ref.watch(coachProCheckinCadenceServiceProvider)
      .get(query.relationshipId);
});
