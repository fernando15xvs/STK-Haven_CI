import 'package:core/domain/models/coach_program_assignment.dart';

enum CoachProProgramRevisionSource {
  legacyBaseline,
  coachRevision;

  static CoachProProgramRevisionSource parse(String? value) => switch (value) {
        'legacy_baseline' => CoachProProgramRevisionSource.legacyBaseline,
        'coach_revision' => CoachProProgramRevisionSource.coachRevision,
        _ => throw const FormatException('Invalid program revision source'),
      };

  String get label => switch (this) {
        CoachProProgramRevisionSource.legacyBaseline => 'Base histórica',
        CoachProProgramRevisionSource.coachRevision => 'Revisión del coach',
      };
}

class CoachProProgramRevisionSummary {
  final String id;
  final int revisionNumber;
  final String? previousRevisionId;
  final CoachProProgramRevisionSource source;
  final int observedAssignmentVersion;
  final DateTime recordedAt;
  final DateTime? authoredAt;

  const CoachProProgramRevisionSummary({
    required this.id,
    required this.revisionNumber,
    required this.previousRevisionId,
    required this.source,
    required this.observedAssignmentVersion,
    required this.recordedAt,
    required this.authoredAt,
  });

  DateTime get displayDate => authoredAt ?? recordedAt;
}

class CoachProProgramRevisionHistoryPage {
  final String assignmentId;
  final String relationshipId;
  final int currentAssignmentVersion;
  final int totalCount;
  final List<CoachProProgramRevisionSummary> items;

  const CoachProProgramRevisionHistoryPage({
    required this.assignmentId,
    required this.relationshipId,
    required this.currentAssignmentVersion,
    required this.totalCount,
    this.items = const [],
  });
}

class CoachProProgramRevisionRoutineSummary {
  final String id;
  final String name;
  final int position;

  const CoachProProgramRevisionRoutineSummary({
    required this.id,
    required this.name,
    required this.position,
  });
}

class CoachProProgramRevisionPage {
  final String assignmentId;
  final String relationshipId;
  final String revisionId;
  final int revisionNumber;
  final String? previousRevisionId;
  final CoachProProgramRevisionSource source;
  final int observedAssignmentVersion;
  final String name;
  final int durationWeeks;
  final Set<int> trainingWeekdays;
  final DateTime startsOn;
  final DateTime recordedAt;
  final DateTime? authoredAt;
  final String? routineName;
  final int totalCount;
  final List<CoachProProgramRevisionRoutineSummary> routines;
  final List<AssignedExerciseSnapshot> exercises;

  const CoachProProgramRevisionPage({
    required this.assignmentId,
    required this.relationshipId,
    required this.revisionId,
    required this.revisionNumber,
    required this.previousRevisionId,
    required this.source,
    required this.observedAssignmentVersion,
    required this.name,
    required this.durationWeeks,
    required this.trainingWeekdays,
    required this.startsOn,
    required this.recordedAt,
    required this.authoredAt,
    required this.totalCount,
    this.routineName,
    this.routines = const [],
    this.exercises = const [],
  });

  DateTime get displayDate => authoredAt ?? recordedAt;
}
