/// Whether the engine recommends changing or maintaining the reference load.
enum ProgressionType {
  /// Consistent evidence supports a small load increase.
  increase,

  /// Keep the current reference while consolidating reps or execution.
  maintain,

  /// A temporary reduction may help after a detected plateau.
  deload,

  /// There is not enough reliable data to calculate a reference.
  insufficientData,
}

/// Recovery context used to prevent load increases on cautious days.
enum ProgressionReadiness {
  unknown,
  ready,
  caution,
}

/// Evidence that explains why a progression result was produced.
enum ProgressionReason {
  consistentTopRange,
  confirmTopRange,
  buildRepetitions,
  incompleteWorkSets,
  missingRir,
  effortTooHigh,
  recoveryCaution,
  invalidLoad,
  plateau,

  /// The latest evidence comes from a routine whose rep range is not directly
  /// comparable with the current target. The reference is intentionally kept
  /// conservative and contextualized with e1RM/RIR instead of copied blindly.
  differentRepContext,
}

/// A structured progression suggestion produced by [ProgressionEngine].
///
/// The domain never formats unit-specific strings. The presentation layer uses
/// [FitnessFormatter.formatProgressionTarget] to build the display text.
class ProgressionSuggestion {
  final String exerciseId;
  final String exerciseName;

  /// Current representative working weight in canonical kg.
  final double currentWeightKg;

  /// Suggested weight in canonical kg. Never formatted here — UI converts.
  final double suggestedWeightKg;
  final int suggestedRepsMin;
  final int suggestedRepsMax;
  final ProgressionType type;
  final ProgressionReason reason;

  /// Number of recent sessions considered for this result.
  final int evidenceSessions;

  /// Optional source context from Exercise Memory. These fields let the UI
  /// explain cross-routine evidence without coupling exercise identity to a
  /// routine.
  final String? sourceRoutineName;
  final DateTime? sourcePerformedAt;
  final int? sourceRepsMin;
  final int? sourceRepsMax;
  final double? sourceLastWeightKg;
  final int? sourceLastReps;
  final int? sourceLastRir;
  final bool differentContext;

  /// Conservative estimated 1RM in canonical kg when context differs. It is
  /// evidence only, never a direct prescription.
  final double? sourceEstimated1RmKg;

  const ProgressionSuggestion({
    required this.exerciseId,
    required this.exerciseName,
    required this.currentWeightKg,
    required this.suggestedWeightKg,
    required this.suggestedRepsMin,
    required this.suggestedRepsMax,
    required this.type,
    required this.reason,
    required this.evidenceSessions,
    this.sourceRoutineName,
    this.sourcePerformedAt,
    this.sourceRepsMin,
    this.sourceRepsMax,
    this.sourceLastWeightKg,
    this.sourceLastReps,
    this.sourceLastRir,
    this.differentContext = false,
    this.sourceEstimated1RmKg,
  });
}
