class ActiveProgramState {
  final String presetProgramId;
  final int presetVersion;
  final String programNameSnapshot;
  final DateTime startedAt;
  final int durationWeeks;
  final List<String> generatedRoutineIds;
  final bool isActive;

  const ActiveProgramState({
    required this.presetProgramId,
    required this.presetVersion,
    required this.programNameSnapshot,
    required this.startedAt,
    required this.durationWeeks,
    required this.generatedRoutineIds,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'presetProgramId': presetProgramId,
      'presetVersion': presetVersion,
      'programNameSnapshot': programNameSnapshot,
      'startedAt': startedAt.toIso8601String(),
      'durationWeeks': durationWeeks,
      'generatedRoutineIds': generatedRoutineIds,
      'isActive': isActive,
    };
  }

  factory ActiveProgramState.fromJson(Map<String, dynamic> json) {
    return ActiveProgramState(
      presetProgramId: json['presetProgramId'] as String,
      presetVersion: json['presetVersion'] as int,
      programNameSnapshot: json['programNameSnapshot'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      durationWeeks: json['durationWeeks'] as int,
      generatedRoutineIds: List<String>.from(json['generatedRoutineIds'] as List),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  ActiveProgramState copyWith({
    String? presetProgramId,
    int? presetVersion,
    String? programNameSnapshot,
    DateTime? startedAt,
    int? durationWeeks,
    List<String>? generatedRoutineIds,
    bool? isActive,
  }) {
    return ActiveProgramState(
      presetProgramId: presetProgramId ?? this.presetProgramId,
      presetVersion: presetVersion ?? this.presetVersion,
      programNameSnapshot: programNameSnapshot ?? this.programNameSnapshot,
      startedAt: startedAt ?? this.startedAt,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      generatedRoutineIds: generatedRoutineIds ?? this.generatedRoutineIds,
      isActive: isActive ?? this.isActive,
    );
  }
}
