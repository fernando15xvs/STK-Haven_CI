import 'package:core/domain/models/coach_program_assignment.dart';

class CoachProgramRevisionState {
  final String assignmentId;
  final String relationshipId;
  final AssignedProgramStatus assignmentStatus;
  final int currentAssignmentVersion;
  final String? acceptedRevisionId;
  final int? acceptedRevisionNumber;
  final DateTime? acceptedAt;
  final String? latestRevisionId;
  final int? latestRevisionNumber;
  final String? latestSourceKind;
  final DateTime? latestRecordedAt;
  final DateTime? latestAuthoredAt;
  final bool revisionAccessActive;
  final bool hasPendingRevision;
  final bool canAcceptLatest;

  const CoachProgramRevisionState({
    required this.assignmentId,
    required this.relationshipId,
    required this.assignmentStatus,
    required this.currentAssignmentVersion,
    required this.acceptedRevisionId,
    required this.acceptedRevisionNumber,
    required this.acceptedAt,
    required this.latestRevisionId,
    required this.latestRevisionNumber,
    required this.latestSourceKind,
    required this.latestRecordedAt,
    required this.latestAuthoredAt,
    required this.revisionAccessActive,
    required this.hasPendingRevision,
    required this.canAcceptLatest,
  });

  DateTime? get latestDisplayDate => latestAuthoredAt ?? latestRecordedAt;
}

class ClientProgramRevisionRoutineSummary {
  final String id;
  final String name;
  final int position;
  final String notes;

  const ClientProgramRevisionRoutineSummary({
    required this.id,
    required this.name,
    required this.position,
    this.notes = '',
  });
}

class ClientProgramRevisionPage {
  final String assignmentId;
  final String relationshipId;
  final String revisionId;
  final int revisionNumber;
  final String? previousRevisionId;
  final String sourceKind;
  final int observedAssignmentVersion;
  final String name;
  final String notes;
  final int durationWeeks;
  final Set<int> trainingWeekdays;
  final DateTime startsOn;
  final DateTime recordedAt;
  final DateTime? authoredAt;
  final DateTime? acceptedAt;
  final bool isAccepted;
  final bool canAccept;
  final String? routineName;
  final int totalCount;
  final List<ClientProgramRevisionRoutineSummary> routines;
  final List<AssignedExerciseSnapshot> exercises;

  const ClientProgramRevisionPage({
    required this.assignmentId,
    required this.relationshipId,
    required this.revisionId,
    required this.revisionNumber,
    required this.previousRevisionId,
    required this.sourceKind,
    required this.observedAssignmentVersion,
    required this.name,
    this.notes = '',
    required this.durationWeeks,
    required this.trainingWeekdays,
    required this.startsOn,
    required this.recordedAt,
    required this.authoredAt,
    required this.acceptedAt,
    required this.isAccepted,
    required this.canAccept,
    required this.totalCount,
    this.routineName,
    this.routines = const [],
    this.exercises = const [],
  });

  DateTime get displayDate => authoredAt ?? recordedAt;
}

class CoachProgramRevisionAcceptanceResult {
  final String assignmentId;
  final String revisionId;
  final int revisionNumber;
  final DateTime acceptedAt;
  final bool alreadyAccepted;
  final int currentAssignmentVersion;

  const CoachProgramRevisionAcceptanceResult({
    required this.assignmentId,
    required this.revisionId,
    required this.revisionNumber,
    required this.acceptedAt,
    required this.alreadyAccepted,
    required this.currentAssignmentVersion,
  });
}


class AcceptedProgramRevisionSnapshot {
  final String assignmentId;
  final String relationshipId;
  final String revisionId;
  final int revisionNumber;
  final String sourceKind;
  final String name;
  final String notes;
  final int durationWeeks;
  final Set<int> trainingWeekdays;
  final DateTime startsOn;
  final DateTime acceptedAt;
  final List<AssignedRoutineSnapshot> routines;

  const AcceptedProgramRevisionSnapshot({
    required this.assignmentId,
    required this.relationshipId,
    required this.revisionId,
    required this.revisionNumber,
    required this.sourceKind,
    required this.name,
    required this.notes,
    required this.durationWeeks,
    required this.trainingWeekdays,
    required this.startsOn,
    required this.acceptedAt,
    required this.routines,
  });
}
