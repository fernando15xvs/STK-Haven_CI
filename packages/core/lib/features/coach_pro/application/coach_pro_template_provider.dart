import 'package:core/features/coach_pro/data/coach_pro_template_service.dart';
import 'package:core/features/coach_pro/domain/coach_pro_template.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final coachProTemplateServiceProvider = Provider<CoachProTemplateService>(
  (ref) => CoachProTemplateService(Supabase.instance.client),
);

typedef CoachProTemplateQuery = ({String userId, int offset});

/// Session-keyed, page-scoped: never retain template metadata across logout.
final coachProTemplatePageProvider = FutureProvider.autoDispose
    .family<CoachProTemplatePage?, CoachProTemplateQuery>((ref, query) async {
  final identity = ref.watch(
    appIdentityProvider.select((state) => (state.signedIn, state.userId)),
  );
  if (!identity.$1 || identity.$2 == null || identity.$2 != query.userId) {
    return null;
  }
  return ref.watch(coachProTemplateServiceProvider).list(offset: query.offset);
});
