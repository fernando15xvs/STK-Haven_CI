import 'package:core/features/coach_pro/data/coach_pro_nutrition_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final coachProNutritionServiceProvider = Provider<CoachProNutritionService>(
  (ref) => CoachProNutritionService(Supabase.instance.client));
final coachProNutritionProvider = FutureProvider.autoDispose
    .family<CoachProNutritionPage?, CoachProNutritionQuery>((ref, query) async {
  final identity = ref.watch(appIdentityProvider.select((s) => (s.signedIn, s.userId)));
  if (!identity.$1 || identity.$2 == null) return null;
  return ref.watch(coachProNutritionServiceProvider).load(query);
});
