import 'package:core/core/services/supabase_client_gateway.dart';
import 'package:core/features/coach_pro/data/coach_pro_program_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:riverpod/riverpod.dart';

final coachProProgramServiceProvider = Provider<CoachProProgramService>(
  (ref) => CoachProProgramService(CoreSupabaseClient.client),
);
final coachProProgramPageProvider = FutureProvider.autoDispose
    .family<CoachProProgramPage?, CoachProProgramQuery>((ref, query) async {
  final identity = ref.watch(appIdentityProvider.select((s) => (s.signedIn, s.userId)));
  if (!identity.$1 || identity.$2 == null) return null;
  return ref.watch(coachProProgramServiceProvider).load(query);
});
