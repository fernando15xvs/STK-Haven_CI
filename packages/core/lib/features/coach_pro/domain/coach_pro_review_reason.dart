import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/domain/models/coach_relationship.dart';

/// Why an authorized client appears in the operational review inbox.
enum CoachProReviewReason {
  progressSnapshotMissing,
  lastWorkoutUnknown,
  lastSharedWorkoutNeedsReview,
}

extension CoachProReviewReasonLabel on CoachProReviewReason {
  String get description => switch (this) {
    CoachProReviewReason.progressSnapshotMissing =>
      'No hay una instantánea de progreso disponible.',
    CoachProReviewReason.lastWorkoutUnknown =>
      'No se compartió una fecha de último entrenamiento.',
    CoachProReviewReason.lastSharedWorkoutNeedsReview =>
      'El último entrenamiento compartido requiere revisión.',
  };
}

/// The server decides the seven-day rule. Never infer actual inactivity from
/// missing data or recalculate server deadlines on the device.
CoachProReviewReason? coachProReviewReason(CoachProClientSummary client) {
  if (client.relationshipStatus != CoachRelationshipStatus.active ||
      !client.permissions.contains(CoachPermission.viewProgress) ||
      !client.needsReview) return null;
  if (!client.progressAvailable) {
    return CoachProReviewReason.progressSnapshotMissing;
  }
  if (client.lastWorkoutAt == null) {
    return CoachProReviewReason.lastWorkoutUnknown;
  }
  return CoachProReviewReason.lastSharedWorkoutNeedsReview;
}
