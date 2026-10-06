import 'package:core/features/coach_pro/data/coach_pro_program_revision_service.dart';
import 'package:core/features/coach_pro/domain/coach_pro_program_revision.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final coachProProgramRevisionServiceProvider =
    Provider<CoachProProgramRevisionService>(
  (ref) => CoachProProgramRevisionService(Supabase.instance.client),
);

final coachProProgramRevisionHistoryProvider = FutureProvider.autoDispose
    .family<CoachProProgramRevisionHistoryPage?,
        CoachProProgramRevisionHistoryQuery>((ref, query) async {
  final identity = ref.watch(
    appIdentityProvider.select((state) => (state.signedIn, state.userId)),
  );
  if (!identity.$1 || identity.$2 == null) return null;
  return ref.watch(coachProProgramRevisionServiceProvider).list(query);
});

final coachProProgramRevisionDetailProvider = FutureProvider.autoDispose
    .family<CoachProProgramRevisionPage?,
        CoachProProgramRevisionDetailQuery>((ref, query) async {
  final identity = ref.watch(
    appIdentityProvider.select((state) => (state.signedIn, state.userId)),
  );
  if (!identity.$1 || identity.$2 == null) return null;
  return ref.watch(coachProProgramRevisionServiceProvider).load(query);
});
