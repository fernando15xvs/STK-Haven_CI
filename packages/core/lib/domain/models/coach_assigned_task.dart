import 'package:core/domain/models/habit_task.dart';

enum CoachAssignedTaskStatus {
  active,
  archived,
}

enum CoachTaskOccurrenceStatus {
  completed,
  skipped,
}

class CoachAssignedTask {
  final String id;
  final String relationshipId;
  final String coachUserId;
  final String clientUserId;
  final String title;
  final String category;
  final HabitTaskType type;
  final int targetMinutes;
  final HabitRecurrenceType recurrence;
  final Set<int> weekdays;
  final DateTime startsOn;
  final DateTime? dueAt;
  final DateTime? endsOn;
  final String coachInstructions;
  final CoachAssignedTaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CoachAssignedTask({
    required this.id,
    required this.relationshipId,
    required this.coachUserId,
    required this.clientUserId,
    required this.title,
    required this.category,
    required this.type,
    required this.targetMinutes,
    required this.recurrence,
    required this.weekdays,
    required this.startsOn,
    this.dueAt,
    this.endsOn,
    required this.coachInstructions,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool isCoach(String? userId) => userId != null && coachUserId == userId;

  bool isClient(String? userId) => userId != null && clientUserId == userId;

  bool get isActive => status == CoachAssignedTaskStatus.active;

  HabitTask toLocalHabitTask({
    bool reminderEnabled = false,
  }) {
    return HabitTask(
      id: 'coach::$id',
      title: title,
      category: category,
      type: type,
      targetMinutes: targetMinutes,
      recurrence: recurrence,
      weekdays: weekdays,
      scheduledAt: dueAt ?? startsOn,
      createdAt: createdAt,
      updatedAt: updatedAt,
      source: HabitTaskSource.coach,
      visibility: HabitTaskVisibility.shareable,
      faithSpecific: false,
      notes: coachInstructions,
      sourceReference: id,
      reminderEnabled: reminderEnabled,
      archived: !isActive,
    );
  }

  Map<String, dynamic> toAssignmentPayload() => <String, dynamic>{
        'title': title,
        'category': category,
        'task_type': type.name,
        'target_minutes': targetMinutes,
        'recurrence_type': recurrence.name,
        'weekdays': weekdays.toList()..sort(),
        'starts_on': _dateOnly(startsOn),
        'due_at': dueAt?.toUtc().toIso8601String(),
        'ends_on': endsOn == null ? null : _dateOnly(endsOn!),
        'coach_instructions': coachInstructions,
      };

  factory CoachAssignedTask.fromJson(Map<String, dynamic> json) {
    return CoachAssignedTask(
      id: '${json['id'] ?? ''}',
      relationshipId: '${json['relationship_id'] ?? ''}',
      coachUserId: '${json['coach_user_id'] ?? ''}',
      clientUserId: '${json['client_user_id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      category: '${json['category'] ?? 'General'}',
      type: _enumByName(
            HabitTaskType.values,
            json['task_type']?.toString(),
          ) ??
          HabitTaskType.checklist,
      targetMinutes: ((json['target_minutes'] as num?)?.toInt() ?? 0)
          .clamp(0, 1440)
          .toInt(),
      recurrence: _enumByName(
            HabitRecurrenceType.values,
            json['recurrence_type']?.toString(),
          ) ??
          HabitRecurrenceType.once,
      weekdays: (json['weekdays'] as List? ?? const [])
          .map((value) => (value as num?)?.toInt())
          .whereType<int>()
          .where((value) => value >= 1 && value <= 7)
          .toSet(),
      startsOn:
          DateTime.tryParse('${json['starts_on']}') ?? DateTime.now(),
      dueAt: json['due_at'] == null
          ? null
          : DateTime.tryParse('${json['due_at']}'),
      endsOn: json['ends_on'] == null
          ? null
          : DateTime.tryParse('${json['ends_on']}'),
      coachInstructions: '${json['coach_instructions'] ?? ''}',
      status: _enumByName(
            CoachAssignedTaskStatus.values,
            json['status']?.toString(),
          ) ??
          CoachAssignedTaskStatus.archived,
      createdAt:
          DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse('${json['updated_at']}') ?? DateTime.now(),
    );
  }
}

class CoachTaskOccurrence {
  final String id;
  final String taskId;
  final String clientUserId;
  final DateTime occurrenceDate;
  final CoachTaskOccurrenceStatus status;
  final int minutesSpent;
  final DateTime? completedAt;
  final DateTime createdAt;

  const CoachTaskOccurrence({
    required this.id,
    required this.taskId,
    required this.clientUserId,
    required this.occurrenceDate,
    required this.status,
    required this.minutesSpent,
    this.completedAt,
    required this.createdAt,
  });

  factory CoachTaskOccurrence.fromJson(Map<String, dynamic> json) {
    return CoachTaskOccurrence(
      id: '${json['id'] ?? ''}',
      taskId: '${json['task_id'] ?? ''}',
      clientUserId: '${json['client_user_id'] ?? ''}',
      occurrenceDate:
          DateTime.tryParse('${json['occurrence_date']}') ?? DateTime.now(),
      status: _enumByName(
            CoachTaskOccurrenceStatus.values,
            json['status']?.toString(),
          ) ??
          CoachTaskOccurrenceStatus.skipped,
      minutesSpent: ((json['minutes_spent'] as num?)?.toInt() ?? 0)
          .clamp(0, 1440)
          .toInt(),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.tryParse('${json['completed_at']}'),
      createdAt:
          DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
    );
  }
}

class CoachTaskComment {
  final String id;
  final String taskId;
  final DateTime? occurrenceDate;
  final String authorUserId;
  final String body;
  final DateTime createdAt;

  const CoachTaskComment({
    required this.id,
    required this.taskId,
    this.occurrenceDate,
    required this.authorUserId,
    required this.body,
    required this.createdAt,
  });

  factory CoachTaskComment.fromJson(Map<String, dynamic> json) {
    return CoachTaskComment(
      id: '${json['id'] ?? ''}',
      taskId: '${json['task_id'] ?? ''}',
      occurrenceDate: json['occurrence_date'] == null
          ? null
          : DateTime.tryParse('${json['occurrence_date']}'),
      authorUserId: '${json['author_user_id'] ?? ''}',
      body: '${json['body'] ?? ''}',
      createdAt:
          DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
    );
  }
}

class CoachTaskAdherence {
  final String clientUserId;
  final int days;
  final int dueCount;
  final int completedCount;
  final int skippedCount;
  final int pendingCount;
  final double adherencePercent;

  const CoachTaskAdherence({
    required this.clientUserId,
    required this.days,
    required this.dueCount,
    required this.completedCount,
    required this.skippedCount,
    required this.pendingCount,
    required this.adherencePercent,
  });

  factory CoachTaskAdherence.fromJson(Map<String, dynamic> json) {
    return CoachTaskAdherence(
      clientUserId: '${json['client_user_id'] ?? ''}',
      days: (json['days'] as num?)?.toInt() ?? 30,
      dueCount: (json['due_count'] as num?)?.toInt() ?? 0,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      skippedCount: (json['skipped_count'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      adherencePercent:
          (json['adherence_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

T? _enumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

String _dateOnly(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
