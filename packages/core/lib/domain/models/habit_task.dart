enum HabitTaskType {
  checklist,
  readingTimer,
  studySession,
  reflection,
  custom,
}

enum HabitRecurrenceType {
  once,
  daily,
  weekly,
}

enum HabitTaskSource {
  user,
  plan,
  coach,
}

enum HabitTaskVisibility {
  private,
  shareable,
}

class HabitTask {
  final String id;
  final String title;
  final String category;
  final HabitTaskType type;
  final int targetMinutes;
  final double? targetQuantity;
  final String quantityUnit;
  final HabitRecurrenceType recurrence;
  final Set<int> weekdays;
  final DateTime? scheduledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final HabitTaskSource source;
  final HabitTaskVisibility visibility;
  final bool faithSpecific;
  final String reference;
  final String notes;
  final String sourceReference;
  final bool reminderEnabled;
  final bool archived;
  /// Flexible weekly goal (distinct days), independent of fixed weekdays.
  final int? weeklyGoal;
  final DateTime? pausedUntil;
  final DateTime? pausedFrom;
  final List<HabitPauseInterval> pauseHistory;

  const HabitTask({
    required this.id,
    required this.title,
    this.category = 'General',
    this.type = HabitTaskType.checklist,
    this.targetMinutes = 0,
    this.targetQuantity, this.quantityUnit = '',
    this.recurrence = HabitRecurrenceType.once,
    this.weekdays = const <int>{},
    this.scheduledAt,
    required this.createdAt,
    required this.updatedAt,
    this.source = HabitTaskSource.user,
    this.visibility = HabitTaskVisibility.private,
    this.faithSpecific = false,
    this.reference = '',
    this.notes = '',
    this.sourceReference = '',
    this.reminderEnabled = false,
    this.archived = false,
    this.weeklyGoal,
    this.pausedUntil, this.pausedFrom, this.pauseHistory=const [],
  });

  HabitTask copyWith({
    String? id,
    String? title,
    String? category,
    HabitTaskType? type,
    int? targetMinutes,
    double? targetQuantity, bool clearTargetQuantity=false, String? quantityUnit,
    HabitRecurrenceType? recurrence,
    Set<int>? weekdays,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    HabitTaskSource? source,
    HabitTaskVisibility? visibility,
    bool? faithSpecific,
    String? reference,
    String? notes,
    String? sourceReference,
    bool? reminderEnabled,
    bool? archived,
    int? weeklyGoal, bool clearWeeklyGoal = false,
    DateTime? pausedUntil, DateTime? pausedFrom, bool clearPause = false,List<HabitPauseInterval>? pauseHistory,
  }) {
    return HabitTask(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      type: type ?? this.type,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      targetQuantity:clearTargetQuantity?null:targetQuantity??this.targetQuantity,
      quantityUnit:quantityUnit??this.quantityUnit,
      recurrence: recurrence ?? this.recurrence,
      weekdays: weekdays ?? this.weekdays,
      scheduledAt:
          clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
      visibility: visibility ?? this.visibility,
      faithSpecific: faithSpecific ?? this.faithSpecific,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      sourceReference: sourceReference ?? this.sourceReference,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      archived: archived ?? this.archived,
      weeklyGoal: clearWeeklyGoal ? null : weeklyGoal ?? this.weeklyGoal,
      pausedUntil: clearPause ? null : pausedUntil ?? this.pausedUntil,
      pausedFrom: clearPause ? null : pausedFrom ?? this.pausedFrom,
      pauseHistory:pauseHistory??this.pauseHistory,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'category': category,
        'type': type.name,
        'targetMinutes': targetMinutes,
        if(targetQuantity!=null)'targetQuantity':targetQuantity,
        if(quantityUnit.isNotEmpty)'quantityUnit':quantityUnit,
        'recurrence': recurrence.name,
        'weekdays': weekdays.toList()..sort(),
        'scheduledAt': scheduledAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'source': source.name,
        'visibility': visibility.name,
        'faithSpecific': faithSpecific,
        'reference': reference,
        'notes': notes,
        'sourceReference': sourceReference,
        'reminderEnabled': reminderEnabled,
        'archived': archived,
        if (weeklyGoal != null) 'weeklyGoal': weeklyGoal,
        if (pausedUntil != null) 'pausedUntil': pausedUntil!.toIso8601String(),
        if (pausedFrom != null) 'pausedFrom': pausedFrom!.toIso8601String(),
        if(pauseHistory.isNotEmpty)'pauseHistory':pauseHistory.map((p)=>p.toJson()).toList(),
      };

  factory HabitTask.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse('${json['createdAt']}') ?? DateTime.now();
    final updatedAt =
        DateTime.tryParse('${json['updatedAt']}') ?? createdAt;
    final rawTarget = (json['targetMinutes'] as num?)?.toInt() ?? 0;
    final rawCategory = '${json['category'] ?? 'General'}'.trim();

    return HabitTask(
      id: '${json['id'] ?? ''}'.trim(),
      title: '${json['title'] ?? ''}'.trim(),
      category: rawCategory.isEmpty ? 'General' : rawCategory,
      type: _enumByName(
            HabitTaskType.values,
            json['type']?.toString(),
          ) ??
          HabitTaskType.checklist,
      targetMinutes: rawTarget.clamp(0, 1440).toInt(),
      targetQuantity:(json['targetQuantity'] as num?)?.toDouble(),
      quantityUnit:'${json['quantityUnit']??''}',
      recurrence: _enumByName(
            HabitRecurrenceType.values,
            json['recurrence']?.toString(),
          ) ??
          HabitRecurrenceType.once,
      weekdays: (json['weekdays'] as List? ?? const [])
          .map((value) => (value as num?)?.toInt())
          .whereType<int>()
          .where(
            (value) =>
                value >= DateTime.monday && value <= DateTime.sunday,
          )
          .toSet(),
      scheduledAt: json['scheduledAt'] == null
          ? null
          : DateTime.tryParse('${json['scheduledAt']}'),
      createdAt: createdAt,
      updatedAt: updatedAt,
      source: _enumByName(
            HabitTaskSource.values,
            json['source']?.toString(),
          ) ??
          HabitTaskSource.user,
      visibility: _enumByName(
            HabitTaskVisibility.values,
            json['visibility']?.toString(),
          ) ??
          HabitTaskVisibility.private,
      faithSpecific: json['faithSpecific'] as bool? ?? false,
      reference: '${json['reference'] ?? ''}',
      notes: '${json['notes'] ?? ''}',
      sourceReference: '${json['sourceReference'] ?? ''}',
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      weeklyGoal: (json['weeklyGoal'] as num?)?.toInt().clamp(1, 7).toInt(),
      pausedUntil: DateTime.tryParse('${json['pausedUntil']}'),
      pausedFrom: DateTime.tryParse('${json['pausedFrom']}'),
      pauseHistory:(json['pauseHistory'] as List? ?? const []).whereType<Map>().map((p)=>HabitPauseInterval.fromJson(Map<String,dynamic>.from(p))).whereType<HabitPauseInterval>().toList(),
    );
  }
}

class HabitPauseInterval {
  final DateTime from;
  final DateTime until;
  const HabitPauseInterval(this.from,this.until);
  Map<String,dynamic> toJson()=>{'from':from.toIso8601String(),'until':until.toIso8601String()};
  static HabitPauseInterval? fromJson(Map<String,dynamic> json){
    final from=DateTime.tryParse('${json['from']}'),until=DateTime.tryParse('${json['until']}');
    return from!=null&&until!=null&&until.isAfter(from)?HabitPauseInterval(from,until):null;
  }
}

enum HabitTaskCompletionStatus {
  completed,
  skipped,
}

class HabitTaskCompletion {
  final String id;
  final String taskId;
  final DateTime completedAt;
  final int minutesSpent;
  final double? quantity;
  final String note;
  final HabitTaskCompletionStatus status;

  const HabitTaskCompletion({
    required this.id,
    required this.taskId,
    required this.completedAt,
    this.minutesSpent = 0,
    this.quantity,
    this.note = '',
    this.status = HabitTaskCompletionStatus.completed,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'taskId': taskId,
        'completedAt': completedAt.toIso8601String(),
        'minutesSpent': minutesSpent,
        if(quantity!=null)'quantity':quantity,
        'note': note,
        'status': status.name,
      };

  factory HabitTaskCompletion.fromJson(Map<String, dynamic> json) {
    final minutes = (json['minutesSpent'] as num?)?.toInt() ?? 0;
    return HabitTaskCompletion(
      id: '${json['id'] ?? ''}'.trim(),
      taskId: '${json['taskId'] ?? ''}'.trim(),
      completedAt:
          DateTime.tryParse('${json['completedAt']}') ?? DateTime.now(),
      minutesSpent: minutes.clamp(0, 1440).toInt(),
      quantity:(json['quantity'] as num?)?.toDouble(),
      note: '${json['note'] ?? ''}',
      status: _enumByName(
            HabitTaskCompletionStatus.values,
            json['status']?.toString(),
          ) ??
          HabitTaskCompletionStatus.completed,
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
