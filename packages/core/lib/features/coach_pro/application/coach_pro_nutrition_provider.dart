import 'package:core/core/services/supabase_client_gateway.dart';
import 'package:core/features/coach_pro/data/coach_pro_nutrition_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:riverpod/riverpod.dart';

final coachProNutritionServiceProvider = Provider<CoachProNutritionService>(
  (ref) => CoachProNutritionService(CoreSupabaseClient.client));
final coachProNutritionVersionsProvider = FutureProvider.autoDispose
    .family<CoachProNutritionVersionsPage?, CoachProNutritionQuery>((ref, query) async {
  final identity = ref.watch(appIdentityProvider.select((s) => (s.signedIn, s.userId)));
  if (!identity.$1 || identity.$2 == null) return null;
  return ref.watch(coachProNutritionServiceProvider).listVersions(query);
});
final coachProNutritionProvider = FutureProvider.autoDispose
    .family<CoachProNutritionPage?, CoachProNutritionQuery>((ref, query) async {
  final identity = ref.watch(appIdentityProvider.select((s) => (s.signedIn, s.userId)));
  if (!identity.$1 || identity.$2 == null) return null;
  return ref.watch(coachProNutritionServiceProvider).load(query);
});
