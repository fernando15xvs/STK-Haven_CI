enum CoachRelationshipStatus {
  active,
  paused,
  revoked,
}

enum CoachPermission {
  viewWorkouts('view_workouts'),
  viewProgress('view_progress'),
  viewMeasurements('view_measurements'),
  assignPrograms('assign_programs'),
  viewCheckins('view_checkins'),
  viewNutrition('view_nutrition'),
  comment('comment');

  final String wireName;

  const CoachPermission(this.wireName);

  static CoachPermission? fromWireName(String? value) {
    for (final permission in values) {
      if (permission.wireName == value) return permission;
    }
    return null;
  }
}

class CoachInvitationPreview {
  final String invitationId;
  final String coachUserId;
  final String? coachDisplayName;
  final Set<CoachPermission> permissions;
  final DateTime expiresAt;

  const CoachInvitationPreview({
    required this.invitationId,
    required this.coachUserId,
    this.coachDisplayName,
    this.permissions = const <CoachPermission>{},
    required this.expiresAt,
  });

  factory CoachInvitationPreview.fromJson(Map<String, dynamic> json) {
    final rawPermissions = json['permissions'];
    return CoachInvitationPreview(
      invitationId: '${json['invitation_id'] ?? ''}',
      coachUserId: '${json['coach_user_id'] ?? ''}',
      coachDisplayName: json['coach_display_name']?.toString(),
      permissions: parseCoachPermissions(rawPermissions),
      expiresAt:
          DateTime.tryParse('${json['expires_at']}') ?? DateTime.now(),
    );
  }
}

class CoachClientRelationship {
  final String id;
  final String coachUserId;
  final String clientUserId;
  final CoachRelationshipStatus status;
  final Set<CoachPermission> permissions;
  final DateTime createdAt;
  final DateTime acceptedAt;
  final DateTime updatedAt;
  final DateTime? revokedAt;
  final String? counterpartDisplayName;

  const CoachClientRelationship({
    required this.id,
    required this.coachUserId,
    required this.clientUserId,
    required this.status,
    this.permissions = const <CoachPermission>{},
    required this.createdAt,
    required this.acceptedAt,
    required this.updatedAt,
    this.revokedAt,
    this.counterpartDisplayName,
  });

  factory CoachClientRelationship.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse('${json['created_at']}') ?? DateTime.now();
    final acceptedAt =
        DateTime.tryParse('${json['accepted_at']}') ?? createdAt;
    final updatedAt =
        DateTime.tryParse('${json['updated_at']}') ?? acceptedAt;

    return CoachClientRelationship(
      id: '${json['id'] ?? ''}',
      coachUserId: '${json['coach_user_id'] ?? ''}',
      clientUserId: '${json['client_user_id'] ?? ''}',
      status: _relationshipStatus(json['status']?.toString()),
      permissions: parseCoachPermissions(json['permissions']),
      createdAt: createdAt,
      acceptedAt: acceptedAt,
      updatedAt: updatedAt,
      revokedAt: json['revoked_at'] == null
          ? null
          : DateTime.tryParse('${json['revoked_at']}'),
      counterpartDisplayName: json['counterpart_display_name']?.toString(),
    );
  }

  bool isCoach(String? userId) => userId != null && coachUserId == userId;

  bool isClient(String? userId) => userId != null && clientUserId == userId;

  bool get isActive => status == CoachRelationshipStatus.active;

  bool allows(CoachPermission permission) =>
      isActive && permissions.contains(permission);
}

Set<CoachPermission> parseCoachPermissions(dynamic raw) {
  if (raw is! Map) return const <CoachPermission>{};
  final result = <CoachPermission>{};
  for (final entry in raw.entries) {
    if (entry.value != true) continue;
    final permission =
        CoachPermission.fromWireName(entry.key.toString());
    if (permission != null) result.add(permission);
  }
  return result;
}

Map<String, bool> coachPermissionsToJson(
  Iterable<CoachPermission> permissions,
) {
  final selected = permissions.toSet();
  return <String, bool>{
    for (final permission in CoachPermission.values)
      permission.wireName: selected.contains(permission),
  };
}

CoachRelationshipStatus _relationshipStatus(String? value) {
  for (final status in CoachRelationshipStatus.values) {
    if (status.name == value) return status;
  }
  return CoachRelationshipStatus.revoked;
}
