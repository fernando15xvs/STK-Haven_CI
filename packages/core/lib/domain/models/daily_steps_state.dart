class DailyStepsState {
  final String dateString;
  final int steps;
  final bool deviceSynced;
  final DateTime? lastSyncedAt;

  const DailyStepsState({
    required this.dateString,
    this.steps = 0,
    this.deviceSynced = false,
    this.lastSyncedAt,
  });

  DailyStepsState copyWith({
    String? dateString,
    int? steps,
    bool? deviceSynced,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
  }) {
    return DailyStepsState(
      dateString: dateString ?? this.dateString,
      steps: steps ?? this.steps,
      deviceSynced: deviceSynced ?? this.deviceSynced,
      lastSyncedAt:
          clearLastSyncedAt ? null : (lastSyncedAt ?? this.lastSyncedAt),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dateString': dateString,
        'steps': steps,
        'deviceSynced': deviceSynced,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      };

  factory DailyStepsState.fromJson(Map<String, dynamic> json) {
    final rawSync = json['lastSyncedAt']?.toString();
    return DailyStepsState(
      dateString: json['dateString']?.toString() ?? '',
      steps: ((json['steps'] as num?)?.toInt() ?? 0).clamp(0, 250000),
      deviceSynced: json['deviceSynced'] as bool? ?? false,
      lastSyncedAt:
          rawSync == null || rawSync.isEmpty ? null : DateTime.tryParse(rawSync),
    );
  }
}
