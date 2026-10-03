import 'package:core/features/coach_pro/data/coach_pro_task_comments_service.dart';
import 'package:core/features/coach_pro/data/coach_pro_task_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final coachProTaskCommentsServiceProvider = Provider<CoachProTaskCommentsService>(
  (ref) => CoachProTaskCommentsService(Supabase.instance.client),
);
final coachProTaskCommentsProvider = FutureProvider.autoDispose
    .family<CoachProTaskCommentsPage?, CoachProTaskQuery>((ref, query) async {
  final identity = ref.watch(appIdentityProvider.select((s) => (s.signedIn, s.userId)));
  if (!identity.$1 || identity.$2 == null) return null;
  return ref.watch(coachProTaskCommentsServiceProvider).load(query);
});
