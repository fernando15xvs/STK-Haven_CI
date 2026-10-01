import 'package:core/domain/models/coach_relationship.dart';

class CoachProClientSummary {
  final String relationshipId;
  final String clientUserId;
  final String displayName;
  final CoachRelationshipStatus relationshipStatus;
  final Set<CoachPermission> permissions;
  final DateTime relationshipUpdatedAt;
  final bool progressAvailable;
  final int? workouts7d;
  final int? workouts30d;
  final double? averageRir7d;
  final DateTime? lastWorkoutAt;
  final DateTime? latestCheckinAt;
  final int activeTaskCount;
  final bool needsReview;
  final int totalCount;

  const CoachProClientSummary({
    required this.relationshipId,
    required this.clientUserId,
    required this.displayName,
    required this.relationshipStatus,
    required this.permissions,
    required this.relationshipUpdatedAt,
    required this.progressAvailable,
    required this.activeTaskCount,
    required this.needsReview,
    required this.totalCount,
    this.workouts7d,
    this.workouts30d,
    this.averageRir7d,
    this.lastWorkoutAt,
    this.latestCheckinAt,
  });

  factory CoachProClientSummary.fromJson(Map<String, dynamic> json) {
    final statusName = json['relationship_status']?.toString();
    final status = CoachRelationshipStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => CoachRelationshipStatus.revoked,
    );

    return CoachProClientSummary(
      relationshipId: json['relationship_id']?.toString() ?? '',
      clientUserId: json['client_user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      relationshipStatus: status,
      permissions: parseCoachPermissions(json['permissions']),
      relationshipUpdatedAt:
          DateTime.tryParse(json['relationship_updated_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      progressAvailable: json['progress_available'] as bool? ?? false,
      workouts7d: (json['workouts_7d'] as num?)?.toInt(),
      workouts30d: (json['workouts_30d'] as num?)?.toInt(),
      averageRir7d: (json['average_rir_7d'] as num?)?.toDouble(),
      lastWorkoutAt: _date(json['last_workout_at']),
      latestCheckinAt: _date(json['latest_checkin_at']),
      activeTaskCount: (json['active_task_count'] as num?)?.toInt() ?? 0,
      needsReview: json['needs_review'] as bool? ?? false,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
