import 'package:core/features/coach_pro/data/coach_pro_task_agenda_service.dart';
import 'package:core/features/coach_pro/domain/coach_pro_task_agenda.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CoachProTaskAgendaQuery = ({
  String userId,
  String relationshipId,
  int offset,
});

final coachProTaskAgendaServiceProvider = Provider<CoachProTaskAgendaService>(
  (ref) => CoachProTaskAgendaService(Supabase.instance.client),
);

/// A single page, invalidated on logout or client-permission changes.
final coachProTaskAgendaPageProvider = FutureProvider.autoDispose
  .family<CoachProAgendaPage?, CoachProTaskAgendaQuery>((ref, query) {
    final user = ref.watch(
      appIdentityProvider.select((s) => (s.signedIn, s.userId)),
    );
    if (!user.$1 || user.$2 != query.userId) return null;
    return ref.watch(coachProTaskAgendaServiceProvider).list(
      relationshipId: query.relationshipId,
      offset: query.offset,
    );
  });
