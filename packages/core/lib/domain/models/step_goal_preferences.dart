enum StepReminderCadence {
  gentle,
  balanced,
}

class StepGoalPreferences {
  final int targetSteps;
  final bool reminderEnabled;
  final StepReminderCadence reminderCadence;

  const StepGoalPreferences({
    this.targetSteps = 10000,
    this.reminderEnabled = false,
    this.reminderCadence = StepReminderCadence.balanced,
  });

  StepGoalPreferences copyWith({
    int? targetSteps,
    bool? reminderEnabled,
    StepReminderCadence? reminderCadence,
  }) {
    return StepGoalPreferences(
      targetSteps: targetSteps ?? this.targetSteps,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderCadence: reminderCadence ?? this.reminderCadence,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'targetSteps': targetSteps,
        'reminderEnabled': reminderEnabled,
        'reminderCadence': reminderCadence.name,
      };

  factory StepGoalPreferences.fromJson(Map<String, dynamic> json) {
    final rawTarget = (json['targetSteps'] as num?)?.toInt() ?? 10000;
    final cadence = switch (json['reminderCadence']?.toString()) {
      'gentle' => StepReminderCadence.gentle,
      'balanced' => StepReminderCadence.balanced,
      _ => StepReminderCadence.balanced,
    };

    return StepGoalPreferences(
      targetSteps: rawTarget.clamp(1000, 50000).toInt(),
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      reminderCadence: cadence,
    );
  }
}
