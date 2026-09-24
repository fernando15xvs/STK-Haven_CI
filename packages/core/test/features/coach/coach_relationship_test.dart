import 'package:core/domain/models/coach_relationship.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Coach permissions', () {
    test('serializes all permissions explicitly and parses true values only', () {
      final encoded = coachPermissionsToJson({
        CoachPermission.viewWorkouts,
        CoachPermission.assignPrograms,
      });

      expect(encoded['view_workouts'], isTrue);
      expect(encoded['assign_programs'], isTrue);
      expect(encoded['view_measurements'], isFalse);

      expect(
        parseCoachPermissions(encoded),
        {
          CoachPermission.viewWorkouts,
          CoachPermission.assignPrograms,
        },
      );
    });

    test('unknown permission keys fail closed', () {
      expect(
        parseCoachPermissions({
          'view_workouts': true,
          'admin': true,
          'view_progress': 'true',
        }),
        {CoachPermission.viewWorkouts},
      );
    });
  });

  group('CoachInvitationPreview', () {
    test('parses invitation without exposing unrelated account fields', () {
      final preview = CoachInvitationPreview.fromJson({
        'invitation_id': 'invite-1',
        'coach_user_id': 'coach-1',
        'coach_display_name': 'Coach',
        'permissions': {
          'view_progress': true,
          'view_measurements': false,
        },
        'expires_at': '2026-09-30T12:00:00.000Z',
      });

      expect(preview.invitationId, 'invite-1');
      expect(preview.coachUserId, 'coach-1');
      expect(preview.coachDisplayName, 'Coach');
      expect(preview.permissions, {CoachPermission.viewProgress});
    });
  });

  group('CoachClientRelationship', () {
    test('active relationship grants only explicit permissions', () {
      final relationship = CoachClientRelationship.fromJson({
        'id': 'rel-1',
        'coach_user_id': 'coach-1',
        'client_user_id': 'client-1',
        'status': 'active',
        'permissions': {
          'view_workouts': true,
          'view_measurements': false,
        },
        'created_at': '2026-09-24T10:00:00.000Z',
        'accepted_at': '2026-09-24T10:05:00.000Z',
        'updated_at': '2026-09-24T10:05:00.000Z',
      });

      expect(relationship.isCoach('coach-1'), isTrue);
      expect(relationship.isClient('client-1'), isTrue);
      expect(relationship.allows(CoachPermission.viewWorkouts), isTrue);
      expect(relationship.allows(CoachPermission.viewMeasurements), isFalse);
    });

    test('revoked relationship denies even persisted true permissions', () {
      final relationship = CoachClientRelationship.fromJson({
        'id': 'rel-1',
        'coach_user_id': 'coach-1',
        'client_user_id': 'client-1',
        'status': 'revoked',
        'permissions': {'view_workouts': true},
        'created_at': '2026-09-24T10:00:00.000Z',
        'accepted_at': '2026-09-24T10:05:00.000Z',
        'updated_at': '2026-09-24T11:00:00.000Z',
        'revoked_at': '2026-09-24T11:00:00.000Z',
      });

      expect(relationship.isActive, isFalse);
      expect(relationship.allows(CoachPermission.viewWorkouts), isFalse);
    });

    test('unknown relationship status fails closed as revoked', () {
      final relationship = CoachClientRelationship.fromJson({
        'id': 'rel-1',
        'coach_user_id': 'coach-1',
        'client_user_id': 'client-1',
        'status': 'unexpected',
        'permissions': {'view_workouts': true},
        'created_at': '2026-09-24T10:00:00.000Z',
        'accepted_at': '2026-09-24T10:05:00.000Z',
        'updated_at': '2026-09-24T10:05:00.000Z',
      });

      expect(relationship.status, CoachRelationshipStatus.revoked);
      expect(relationship.allows(CoachPermission.viewWorkouts), isFalse);
    });
  });
}
