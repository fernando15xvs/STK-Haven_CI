enum PRType {
  maxWeight,
  estimated1RM,
  bestSetVolume,
}

class PersonalRecordEvent {
  final String id;
  final String workoutSessionId;
  final String exerciseId;
  final String exerciseNameSnapshot;
  final PRType type;
  final double previousValue;
  final double newValue;
  final DateTime achievedAt;

  const PersonalRecordEvent({
    required this.id,
    required this.workoutSessionId,
    required this.exerciseId,
    required this.exerciseNameSnapshot,
    required this.type,
    required this.previousValue,
    required this.newValue,
    required this.achievedAt,
  });
}
