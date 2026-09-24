class StudyPlanStep {
  final int index;
  final String title;
  final String reference;
  final int targetMinutes;

  const StudyPlanStep({
    required this.index,
    required this.title,
    required this.reference,
    this.targetMinutes = 10,
  });
}

class StudyPlanDefinition {
  final String id;
  final String title;
  final String description;
  final List<StudyPlanStep> steps;
  final bool faithSpecific;

  const StudyPlanDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.steps,
    this.faithSpecific = true,
  });
}

class StudyPlanEnrollment {
  final String id;
  final String planId;
  final DateTime startedAt;
  final DateTime updatedAt;
  final Set<int> completedStepIndices;
  final bool paused;

  const StudyPlanEnrollment({
    required this.id,
    required this.planId,
    required this.startedAt,
    required this.updatedAt,
    this.completedStepIndices = const <int>{},
    this.paused = false,
  });

  int? nextStepIndex(int totalSteps) {
    if (totalSteps <= 0) return null;
    for (var index = 0; index < totalSteps; index++) {
      if (!completedStepIndices.contains(index)) return index;
    }
    return null;
  }

  bool isComplete(int totalSteps) =>
      totalSteps > 0 && nextStepIndex(totalSteps) == null;

  StudyPlanEnrollment copyWith({
    DateTime? updatedAt,
    Set<int>? completedStepIndices,
    bool? paused,
  }) {
    return StudyPlanEnrollment(
      id: id,
      planId: planId,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedStepIndices:
          completedStepIndices ?? this.completedStepIndices,
      paused: paused ?? this.paused,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'planId': planId,
        'startedAt': startedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'completedStepIndices': completedStepIndices.toList()..sort(),
        'paused': paused,
      };

  factory StudyPlanEnrollment.fromJson(Map<String, dynamic> json) {
    final startedAt =
        DateTime.tryParse('${json['startedAt']}') ?? DateTime.now();
    return StudyPlanEnrollment(
      id: '${json['id'] ?? ''}'.trim(),
      planId: '${json['planId'] ?? ''}'.trim(),
      startedAt: startedAt,
      updatedAt:
          DateTime.tryParse('${json['updatedAt']}') ?? startedAt,
      completedStepIndices:
          (json['completedStepIndices'] as List? ?? const [])
              .map((value) => (value as num?)?.toInt())
              .whereType<int>()
              .where((value) => value >= 0)
              .toSet(),
      paused: json['paused'] as bool? ?? false,
    );
  }
}
