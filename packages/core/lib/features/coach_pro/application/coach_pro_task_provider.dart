import 'package:core/features/coach_pro/data/coach_pro_task_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final coachProTaskServiceProvider = Provider<CoachProTaskService>(
  (ref) => CoachProTaskService(Supabase.instance.client),
);
final coachProTaskPageProvider = FutureProvider.autoDispose
    .family<CoachProTaskPage?, CoachProTaskQuery>((ref, query) async {
  final identity = ref.watch(appIdentityProvider.select((s) => (s.signedIn, s.userId)));
  if (!identity.$1 || identity.$2 == null) return null;
  return ref.watch(coachProTaskServiceProvider).load(query);
});
