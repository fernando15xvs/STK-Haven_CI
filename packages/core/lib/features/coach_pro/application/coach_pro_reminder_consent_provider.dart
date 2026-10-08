import 'package:core/features/coach_pro/data/coach_pro_reminder_consent_service.dart';
import 'package:core/features/coach_pro/domain/coach_pro_reminder_consent.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CoachProReminderConsentQuery = ({String userId, String relationshipId});

final coachProReminderConsentServiceProvider = Provider<CoachProReminderConsentService>(
  (ref) => CoachProReminderConsentService(Supabase.instance.client),
);

final coachProReminderConsentProvider = FutureProvider.autoDispose
    .family<CoachProReminderConsent?, CoachProReminderConsentQuery>(
  (ref, query) {
    final identity = ref.watch(
      appIdentityProvider.select((s) => (s.signedIn, s.userId)),
    );
    if (!identity.$1 || identity.$2 != query.userId) return null;
    return ref.watch(coachProReminderConsentServiceProvider)
        .get(query.relationshipId);
  },
);
