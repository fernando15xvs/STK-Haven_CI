import 'package:core/core/constants/muscle_taxonomy_v1.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/domain/models/routine.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/exercises/application/canonical_muscle_projection.dart';

enum AnatomyAuditSource { catalogPrimary, catalogSecondary, historySnapshot }

/// Read-only issue used by local audit tooling. An ambiguous general category
/// can be reported safely at category level, but is NOT a specific muscle.
class AnatomyAuditFinding {
  final AnatomyAuditSource source;
  final String originalLabel;
  final String key;
  final String? safeGroupId;
  final int occurrences;

  const AnatomyAuditFinding({
    required this.source,
    required this.originalLabel,
    required this.key,
    required this.safeGroupId,
    required this.occurrences,
  });

  bool get isUnresolved => safeGroupId == null;
}

class ExerciseAnatomyAuditReport {
  final int catalogExercises;
  final int routineReferences;
  final int historicalExercises;
  final List<String> missingRoutineExerciseIds;
  final List<String> missingHistoricalExerciseIds;
  final List<AnatomyAuditFinding> findings;

  const ExerciseAnatomyAuditReport({
    required this.catalogExercises,
    required this.routineReferences,
    required this.historicalExercises,
    required this.missingRoutineExerciseIds,
    required this.missingHistoricalExerciseIds,
    required this.findings,
  });

  int get unresolvedOccurrences => findings
      .where((finding) => finding.isUnresolved)
      .fold(0, (sum, finding) => sum + finding.occurrences);

  int get broadOrAmbiguousOccurrences =>
      findings.fold(0, (sum, finding) => sum + finding.occurrences);

  /// Includes categories that are safe for group reports but do not identify
  /// an individual muscle, plus labels with no safe mapping.
  bool get hasFindings => findings.isNotEmpty ||
      missingRoutineExerciseIds.isNotEmpty ||
      missingHistoricalExerciseIds.isNotEmpty;
}

/// Produces a local diagnostic without persistence, mutation, network calls,
/// or any inferred attribution for unknown compound labels.
class ExerciseAnatomyAudit {
  const ExerciseAnatomyAudit._();

  static ExerciseAnatomyAuditReport inspect({
    required Iterable<Exercise> catalog,
    Iterable<Routine> routines = const [],
    Iterable<WorkoutSession> history = const [],
  }) {
    final exercises = catalog.toList(growable: false);
    final ids = exercises.map((e) => e.id).toSet();
    final findings = <String, AnatomyAuditFinding>{};
    final missingRoutine = <String>{};
    final missingHistory = <String>{};
    var routineReferences = 0;
    var historicalExercises = 0;

    void inspectLabel(String label, AnatomyAuditSource source) {
      final resolved = MuscleTaxonomyV1.resolveLegacy(label);
      final projection = CanonicalMuscleProjector.resolve(label);
      if (projection == null) return;
      if (resolved.isSpecific && !projection.requiresReview) return;
      final key = '${source.name}:${MuscleTaxonomyV1.normalize(label)}';
      final existing = findings[key];
      findings[key] = AnatomyAuditFinding(
        source: source,
        originalLabel: existing?.originalLabel ?? label.trim(),
        key: key,
        safeGroupId: projection.reportGroupId,
        occurrences: (existing?.occurrences ?? 0) + 1,
      );
    }

    for (final exercise in exercises) {
      inspectLabel(exercise.muscleGroup, AnatomyAuditSource.catalogPrimary);
      for (final secondary in exercise.secondaryMuscles) {
        inspectLabel(secondary, AnatomyAuditSource.catalogSecondary);
      }
    }

    for (final routine in routines) {
      for (final target in routine.exercises) {
        routineReferences++;
        if (!ids.contains(target.exerciseId)) {
          missingRoutine.add(target.exerciseId);
        }
      }
    }

    for (final session in history) {
      for (final exercise in session.exercises) {
        historicalExercises++;
        if (!ids.contains(exercise.exerciseId)) {
          missingHistory.add(exercise.exerciseId);
        }
        // Historical snapshot is the authority for this session. Do not
        // repair it using the mutable current catalog.
        inspectLabel(
          exercise.muscleGroupSnapshot, AnatomyAuditSource.historySnapshot,
        );
      }
    }

    final issues = findings.values.toList(growable: false)
      ..sort((a, b) {
        final source = a.source.index.compareTo(b.source.index);
        return source != 0 ? source : a.key.compareTo(b.key);
      });
    return ExerciseAnatomyAuditReport(
      catalogExercises: exercises.length,
      routineReferences: routineReferences,
      historicalExercises: historicalExercises,
      missingRoutineExerciseIds: List.unmodifiable(missingRoutine.toList()..sort()),
      missingHistoricalExerciseIds: List.unmodifiable(missingHistory.toList()..sort()),
      findings: List.unmodifiable(issues),
    );
  }
}
