class HabitStudyTimerState {
  final String taskId;
  final int targetSeconds;
  final int accumulatedSeconds;
  final DateTime? runningSince;
  final DateTime updatedAt;

  const HabitStudyTimerState({
    required this.taskId,
    required this.targetSeconds,
    this.accumulatedSeconds = 0,
    this.runningSince,
    required this.updatedAt,
  });

  bool get isRunning => runningSince != null;

  int elapsedSecondsAt(DateTime now) {
    final base = accumulatedSeconds < 0 ? 0 : accumulatedSeconds;
    final started = runningSince;
    if (started == null) return base;
    final delta = now.difference(started).inSeconds;
    return base + (delta < 0 ? 0 : delta);
  }

  int remainingSecondsAt(DateTime now) {
    if (targetSeconds <= 0) return 0;
    final remaining = targetSeconds - elapsedSecondsAt(now);
    return remaining < 0 ? 0 : remaining;
  }

  bool isCompleteAt(DateTime now) =>
      targetSeconds > 0 && elapsedSecondsAt(now) >= targetSeconds;

  HabitStudyTimerState pause(DateTime now) {
    return HabitStudyTimerState(
      taskId: taskId,
      targetSeconds: targetSeconds,
      accumulatedSeconds: elapsedSecondsAt(now),
      runningSince: null,
      updatedAt: now,
    );
  }

  HabitStudyTimerState resume(DateTime now) {
    if (isRunning) return this;
    return HabitStudyTimerState(
      taskId: taskId,
      targetSeconds: targetSeconds,
      accumulatedSeconds: accumulatedSeconds,
      runningSince: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'taskId': taskId,
        'targetSeconds': targetSeconds,
        'accumulatedSeconds': accumulatedSeconds,
        'runningSince': runningSince?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HabitStudyTimerState.fromJson(Map<String, dynamic> json) {
    final target = (json['targetSeconds'] as num?)?.toInt() ?? 0;
    final accumulated =
        (json['accumulatedSeconds'] as num?)?.toInt() ?? 0;
    return HabitStudyTimerState(
      taskId: '${json['taskId'] ?? ''}'.trim(),
      targetSeconds: target.clamp(0, 86400).toInt(),
      accumulatedSeconds: accumulated < 0 ? 0 : accumulated,
      runningSince: json['runningSince'] == null
          ? null
          : DateTime.tryParse('${json['runningSince']}'),
      updatedAt:
          DateTime.tryParse('${json['updatedAt']}') ?? DateTime.now(),
    );
  }
}
