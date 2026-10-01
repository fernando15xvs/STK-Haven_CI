import 'package:core/domain/models/coach_pro_client_summary.dart';
import 'package:core/domain/models/coach_relationship.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses permitted dashboard aggregate without inventing hidden data', () {
    final item = CoachProClientSummary.fromJson(<String, dynamic>{
      'relationship_id': 'rel-1',
      'client_user_id': 'client-1',
      'display_name': 'Client One',
      'relationship_status': 'active',
      'permissions': <String, dynamic>{
        'view_progress': true,
        'view_checkins': false,
      },
      'relationship_updated_at': '2026-09-30T12:00:00Z',
      'progress_available': true,
      'workouts_7d': 4,
      'workouts_30d': 15,
      'average_rir_7d': 2.3,
      'last_workout_at': '2026-09-29T12:00:00Z',
      'latest_checkin_at': null,
      'active_task_count': 2,
      'needs_review': false,
      'total_count': 8,
    });

    expect(item.relationshipStatus, CoachRelationshipStatus.active);
    expect(item.permissions, contains(CoachPermission.viewProgress));
    expect(item.permissions, isNot(contains(CoachPermission.viewCheckins)));
    expect(item.workouts7d, 4);
    expect(item.latestCheckinAt, isNull);
    expect(item.totalCount, 8);
  });

  test('null protected aggregates remain null instead of becoming zero', () {
    final item = CoachProClientSummary.fromJson(<String, dynamic>{
      'relationship_id': 'rel-2',
      'client_user_id': 'client-2',
      'relationship_status': 'active',
      'permissions': <String, dynamic>{},
      'relationship_updated_at': '2026-09-30T12:00:00Z',
      'progress_available': false,
      'workouts_7d': null,
      'workouts_30d': null,
      'average_rir_7d': null,
      'last_workout_at': null,
      'latest_checkin_at': null,
      'active_task_count': 0,
      'needs_review': false,
      'total_count': 1,
    });

    expect(item.workouts7d, isNull);
    expect(item.workouts30d, isNull);
    expect(item.averageRir7d, isNull);
    expect(item.lastWorkoutAt, isNull);
  });
}
