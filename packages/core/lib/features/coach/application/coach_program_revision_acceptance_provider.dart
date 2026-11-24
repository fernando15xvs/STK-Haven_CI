import 'package:core/core/services/supabase_client_gateway.dart';
import 'package:core/features/coach/data/coach_program_revision_acceptance_service.dart';
import 'package:core/features/coach/domain/coach_program_revision_acceptance.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:riverpod/riverpod.dart';

final coachProgramRevisionAcceptanceServiceProvider =
    Provider<CoachProgramRevisionAcceptanceService>(
  (ref) => CoachProgramRevisionAcceptanceService(CoreSupabaseClient.client),
);

final coachProgramRevisionStateProvider = FutureProvider.autoDispose
    .family<CoachProgramRevisionState?, String>((ref, assignmentId) async {
  final identity = ref.watch(
    appIdentityProvider.select((state) => (state.signedIn, state.userId)),
  );
  if (!identity.$1 || identity.$2 == null) return null;
  return ref
      .watch(coachProgramRevisionAcceptanceServiceProvider)
      .loadState(assignmentId);
});

final clientProgramRevisionPageProvider = FutureProvider.autoDispose
    .family<ClientProgramRevisionPage?, ClientProgramRevisionPageQuery>(
  (ref, query) async {
    final identity = ref.watch(
      appIdentityProvider.select((state) => (state.signedIn, state.userId)),
    );
    if (!identity.$1 || identity.$2 == null) return null;
    return ref
        .watch(coachProgramRevisionAcceptanceServiceProvider)
        .loadPage(query);
  },
);
