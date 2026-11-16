import 'wellness_goal_change.dart';

class HydrationPreferences {
  final int targetMl;
  final bool reminderEnabled;
  final int reminderHour;
  final String? lastReminderDate;
  /// Bounded record of explicitly applied target edits (not intake data).
  final List<WellnessGoalChange> goalChanges;

  const HydrationPreferences({
    this.targetMl = 3000,
    this.reminderEnabled = false,
    this.reminderHour = 18,
    this.lastReminderDate,
    this.goalChanges = const <WellnessGoalChange>[],
  });

  HydrationPreferences copyWith({
    int? targetMl,
    bool? reminderEnabled,
    int? reminderHour,
    String? lastReminderDate,
    bool clearLastReminderDate = false,
    List<WellnessGoalChange>? goalChanges,
  }) {
    return HydrationPreferences(
      targetMl: targetMl ?? this.targetMl,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      lastReminderDate: clearLastReminderDate
          ? null
          : (lastReminderDate ?? this.lastReminderDate),
      goalChanges: goalChanges ?? this.goalChanges,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'targetMl': targetMl,
        'reminderEnabled': reminderEnabled,
        'reminderHour': reminderHour,
        'lastReminderDate': lastReminderDate,
        'goalChanges': goalChanges.map((e)=>e.toJson()).toList(),
      };

  factory HydrationPreferences.fromJson(Map<String, dynamic> json) {
    final rawTarget = (json['targetMl'] as num?)?.toInt() ?? 3000;
    final rawHour = (json['reminderHour'] as num?)?.toInt() ?? 18;
    return HydrationPreferences(
      targetMl: rawTarget.clamp(1000, 5000).toInt(),
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      reminderHour: rawHour.clamp(6, 22).toInt(),
      lastReminderDate: json['lastReminderDate']?.toString(),
      goalChanges: WellnessGoalChange.restore(json['goalChanges']),
    );
  }
}
