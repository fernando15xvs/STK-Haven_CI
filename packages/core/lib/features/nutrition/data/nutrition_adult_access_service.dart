import 'package:supabase_flutter/supabase_flutter.dart';

class NutritionAdultAccessService {
  final SupabaseClient client;

  const NutritionAdultAccessService(this.client);

  Future<bool> hasVerifiedAccess() async {
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    try {
      final result = await client.rpc('stk_has_adult_nutrition_access');
      return result == true;
    } on PostgrestException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
