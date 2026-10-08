import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/features/coach_pro/domain/coach_pro_review_reason.dart';
import 'package:flutter_test/flutter_test.dart';

CoachProClientSummary client({
  bool consent = true,
  bool available = true,
  bool review = true,
  String status = 'active',
  String? lastWorkout = '2026-09-01T10:00:00Z',
}) => CoachProClientSummary.fromJson({
  'relationship_id': 'relationship',
  'client_user_id': 'client',
  'display_name': 'Client',
  'relationship_status': status,
  'permissions': {'view_progress': consent},
  'progress_available': available,
  'last_workout_at': lastWorkout,
  'needs_review': review,
  'total_count': 1,
});

void main() {
  test('never treats hidden, paused or unflagged data as review evidence', () {
    expect(coachProReviewReason(client(consent: false)), isNull);
    expect(coachProReviewReason(client(status: 'paused')), isNull);
    expect(coachProReviewReason(client(status: 'revoked')), isNull);
    expect(coachProReviewReason(client(review: false)), isNull);
  });

  test('separates missing snapshot from missing workout date', () {
    expect(coachProReviewReason(client(available: false)),
        CoachProReviewReason.progressSnapshotMissing);
    expect(coachProReviewReason(client(lastWorkout: null)),
        CoachProReviewReason.lastWorkoutUnknown);
  });

  test('does not recalculate the server review rule using local clock', () {
    expect(coachProReviewReason(client()),
        CoachProReviewReason.lastSharedWorkoutNeedsReview);
    expect(coachProReviewReason(client(
      review: false, lastWorkout: '2000-01-01T00:00:00Z')), isNull);
    expect(CoachProReviewReason.progressSnapshotMissing.description,
        contains('No hay'));
  });
}
