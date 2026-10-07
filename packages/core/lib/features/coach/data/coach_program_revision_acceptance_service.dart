import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/features/coach/domain/coach_program_revision_acceptance.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef ClientProgramRevisionPageQuery = ({
  String assignmentId,
  String revisionId,
  String? routineId,
  int offset,
});

class CoachProgramRevisionAcceptanceService {
  static const int pageSize = 25;

  final SupabaseClient client;
  const CoachProgramRevisionAcceptanceService(this.client);

  Future<CoachProgramRevisionState> loadState(String assignmentId) async {
    final raw = await client.rpc(
      'stk_get_my_program_revision_state',
      params: {'p_assignment_id': assignmentId},
    );
    if (raw is! Map) {
      throw const FormatException('Invalid program revision state');
    }
    final json = Map<String, dynamic>.from(raw);
    if (json['assignment_id'] != assignmentId ||
        json['relationship_id'] is! String ||
        (json['relationship_id'] as String).isEmpty ||
        !_positiveInt(json['current_assignment_version'], max: 10000) ||
        json['revision_access_active'] is! bool ||
        json['has_pending_revision'] is! bool ||
        json['can_accept_latest'] is! bool) {
      throw const FormatException('Invalid program revision state scope');
    }

    final status = _status(json['assignment_status']?.toString());
    final acceptedRevisionId = _optionalNonEmptyString(
      json['accepted_revision_id'],
    );
    final acceptedRevisionNumber = _optionalPositiveInt(
      json['accepted_revision_number'],
      max: 10000,
    );
    final acceptedAt = _optionalDate(json['accepted_at']);
    final latestRevisionId = _optionalNonEmptyString(json['latest_revision_id']);
    final latestRevisionNumber = _optionalPositiveInt(
      json['latest_revision_number'],
      max: 10000,
    );
    final latestSourceKind = _optionalNonEmptyString(
      json['latest_source_kind'],
    );
    final latestRecordedAt = _optionalDate(json['latest_recorded_at']);
    final latestAuthoredAt = _optionalDate(json['latest_authored_at']);

    if ((acceptedRevisionId == null) != (acceptedRevisionNumber == null) ||
        (acceptedRevisionId == null) != (acceptedAt == null) ||
        (latestRevisionId == null) != (latestRevisionNumber == null) ||
        (latestRevisionId == null) != (latestSourceKind == null) ||
        (latestRevisionId == null) != (latestRecordedAt == null) ||
        (latestSourceKind != null &&
            latestSourceKind != 'legacy_baseline' &&
            latestSourceKind != 'coach_revision') ||
        (latestSourceKind == 'legacy_baseline' && latestAuthoredAt != null) ||
        (latestSourceKind == 'coach_revision' && latestAuthoredAt == null) ||
        (json['has_pending_revision'] == true &&
            (latestRevisionId == null ||
                latestSourceKind != 'coach_revision' ||
                json['revision_access_active'] != true)) ||
        (json['can_accept_latest'] == true &&
            json['has_pending_revision'] != true)) {
      throw const FormatException('Invalid program revision state');
    }

    return CoachProgramRevisionState(
      assignmentId: assignmentId,
      relationshipId: json['relationship_id'] as String,
      assignmentStatus: status,
      currentAssignmentVersion: json['current_assignment_version'] as int,
      acceptedRevisionId: acceptedRevisionId,
      acceptedRevisionNumber: acceptedRevisionNumber,
      acceptedAt: acceptedAt,
      latestRevisionId: latestRevisionId,
      latestRevisionNumber: latestRevisionNumber,
      latestSourceKind: latestSourceKind,
      latestRecordedAt: latestRecordedAt,
      latestAuthoredAt: latestAuthoredAt,
      revisionAccessActive: json['revision_access_active'] as bool,
      hasPendingRevision: json['has_pending_revision'] as bool,
      canAcceptLatest: json['can_accept_latest'] as bool,
    );
  }

  Future<ClientProgramRevisionPage> loadPage(
    ClientProgramRevisionPageQuery query,
  ) async {
    final raw = await client.rpc(
      'stk_get_my_program_revision_page',
      params: {
        'p_assignment_id': query.assignmentId,
        'p_revision_id': query.revisionId,
        'p_revision_routine_id': query.routineId,
        'p_limit': pageSize,
        'p_offset': query.offset,
      },
    );
    if (raw is! Map) {
      throw const FormatException('Invalid client revision page');
    }
    final json = Map<String, dynamic>.from(raw);
    final routine = json['routine'];
    if (json['assignment_id'] != query.assignmentId ||
        json['revision_id'] != query.revisionId ||
        json['relationship_id'] is! String ||
        (json['relationship_id'] as String).isEmpty ||
        !_positiveInt(json['revision_number'], max: 10000) ||
        !_positiveInt(json['observed_assignment_version'], max: 10000) ||
        json['source_kind'] is! String ||
        !const {'legacy_baseline', 'coach_revision'}
            .contains(json['source_kind']) ||
        json['name'] is! String ||
        (json['name'] as String).trim().isEmpty ||
        json['notes'] is! String ||
        !_positiveInt(json['duration_weeks'], max: 104) ||
        json['training_weekdays'] is! List ||
        DateTime.tryParse('${json['starts_on']}') == null ||
        DateTime.tryParse('${json['recorded_at']}') == null ||
        json['is_accepted'] is! bool ||
        json['can_accept'] is! bool ||
        !_nonNegativeInt(json['total_count'], max: 10000) ||
        json['items'] is! List ||
        (query.routineId == null
            ? routine != null
            : routine is! Map ||
                routine['id'] != query.routineId ||
                routine['name'] is! String ||
                (routine['name'] as String).trim().isEmpty ||
                routine['notes'] is! String ||
                routine['position'] is! int ||
                (routine['position'] as int) < 0)) {
      throw const FormatException('Invalid client revision scope');
    }

    final authoredAt = _optionalDate(json['authored_at']);
    final acceptedAt = _optionalDate(json['accepted_at']);
    final sourceKind = json['source_kind'] as String;
    if ((sourceKind == 'legacy_baseline' && authoredAt != null) ||
        (sourceKind == 'coach_revision' && authoredAt == null) ||
        ((json['is_accepted'] as bool) != (acceptedAt != null)) ||
        (json['can_accept'] == true && json['is_accepted'] == true)) {
      throw const FormatException('Invalid client revision state');
    }

    final previousRevisionId = _optionalNonEmptyString(
      json['previous_revision_id'],
    );
    final weekdays = <int>{};
    for (final value in json['training_weekdays'] as List) {
      if (value is! num ||
          value.toInt() != value ||
          value.toInt() < DateTime.monday ||
          value.toInt() > DateTime.sunday) {
        throw const FormatException('Invalid revision weekdays');
      }
      weekdays.add(value.toInt());
    }

    final routines = <ClientProgramRevisionRoutineSummary>[];
    final exercises = <AssignedExerciseSnapshot>[];
    for (final value in json['items'] as List) {
      if (value is! Map) {
        throw const FormatException('Invalid client revision item');
      }
      final row = Map<String, dynamic>.from(value);
      if (row['id'] is! String ||
          (row['id'] as String).isEmpty ||
          row['name'] is! String ||
          (row['name'] as String).trim().isEmpty ||
          row['position'] is! int ||
          (query.routineId == null && row['notes'] is! String) ||
          (row['position'] as int) < 0) {
        throw const FormatException('Invalid client revision item');
      }
      if (query.routineId == null) {
        routines.add(
          ClientProgramRevisionRoutineSummary(
            id: row['id'] as String,
            name: (row['name'] as String).trim(),
            position: row['position'] as int,
            notes: row['notes'] as String,
          ),
        );
      } else {
        for (final key in [
          'target_sets',
          'target_reps_min',
          'target_reps_max',
          'rest_seconds',
          'warmup_sets',
          'approach_sets',
        ]) {
          if (row[key] is! num) {
            throw const FormatException('Invalid revision prescription');
          }
        }
        if (row['unilateral'] is! bool ||
            row['unilateral_target'] is! String) {
          throw const FormatException('Invalid revision prescription');
        }
        exercises.add(AssignedExerciseSnapshot.fromJson(row));
      }
    }

    final totalCount = json['total_count'] as int;
    final visibleCount =
        query.routineId == null ? routines.length : exercises.length;
    if (visibleCount > pageSize || visibleCount > totalCount) {
      throw const FormatException('Invalid client revision count');
    }

    return ClientProgramRevisionPage(
      assignmentId: query.assignmentId,
      relationshipId: json['relationship_id'] as String,
      revisionId: query.revisionId,
      revisionNumber: json['revision_number'] as int,
      previousRevisionId: previousRevisionId,
      sourceKind: sourceKind,
      observedAssignmentVersion: json['observed_assignment_version'] as int,
      name: (json['name'] as String).trim(),
      notes: json['notes'] as String,
      durationWeeks: json['duration_weeks'] as int,
      trainingWeekdays: Set.unmodifiable(weekdays),
      startsOn: DateTime.parse('${json['starts_on']}'),
      recordedAt: DateTime.parse('${json['recorded_at']}'),
      authoredAt: authoredAt,
      acceptedAt: acceptedAt,
      isAccepted: json['is_accepted'] as bool,
      canAccept: json['can_accept'] as bool,
      routineName:
          routine is Map ? (routine['name'] as String).trim() : null,
      totalCount: totalCount,
      routines: List.unmodifiable(routines),
      exercises: List.unmodifiable(exercises),
    );
  }

  Future<AcceptedProgramRevisionSnapshot> loadAcceptedRevision({
    required String assignmentId,
    required String revisionId,
  }) async {
    final routineSummaries = <ClientProgramRevisionRoutineSummary>[];
    ClientProgramRevisionPage? root;
    var offset = 0;

    while (true) {
      final page = await loadPage((
        assignmentId: assignmentId,
        revisionId: revisionId,
        routineId: null,
        offset: offset,
      ));
      _assertAcceptedRevisionPage(page, root);
      root ??= page;
      routineSummaries.addAll(page.routines);
      if (routineSummaries.length >= page.totalCount) break;
      if (page.routines.isEmpty) {
        throw const FormatException('Incomplete accepted revision routines');
      }
      offset += page.routines.length;
    }

    final routines = <AssignedRoutineSnapshot>[];
    for (final summary in routineSummaries) {
      final exercises = <AssignedExerciseSnapshot>[];
      var exerciseOffset = 0;
      while (true) {
        final page = await loadPage((
          assignmentId: assignmentId,
          revisionId: revisionId,
          routineId: summary.id,
          offset: exerciseOffset,
        ));
        _assertAcceptedRevisionPage(page, root);
        if (page.routineName != summary.name) {
          throw const FormatException('Invalid accepted revision routine');
        }
        exercises.addAll(page.exercises);
        if (exercises.length >= page.totalCount) break;
        if (page.exercises.isEmpty) {
          throw const FormatException('Incomplete accepted revision exercises');
        }
        exerciseOffset += page.exercises.length;
      }
      routines.add(
        AssignedRoutineSnapshot(
          id: summary.id,
          position: summary.position,
          name: summary.name,
          notes: summary.notes,
          exercises: List.unmodifiable(exercises),
        ),
      );
    }

    final accepted = root;
    if (accepted.acceptedAt == null ||
        routines.isEmpty ||
        routines.length != accepted.totalCount) {
      throw const FormatException('Invalid accepted revision snapshot');
    }

    return AcceptedProgramRevisionSnapshot(
      assignmentId: accepted.assignmentId,
      relationshipId: accepted.relationshipId,
      revisionId: accepted.revisionId,
      revisionNumber: accepted.revisionNumber,
      sourceKind: accepted.sourceKind,
      name: accepted.name,
      notes: accepted.notes,
      durationWeeks: accepted.durationWeeks,
      trainingWeekdays: accepted.trainingWeekdays,
      startsOn: accepted.startsOn,
      acceptedAt: accepted.acceptedAt!,
      routines: List.unmodifiable(routines),
    );
  }

  static void _assertAcceptedRevisionPage(
    ClientProgramRevisionPage page,
    ClientProgramRevisionPage? root,
  ) {
    if (!page.isAccepted ||
        page.acceptedAt == null ||
        page.canAccept ||
        (root != null &&
            (page.assignmentId != root.assignmentId ||
                page.relationshipId != root.relationshipId ||
                page.revisionId != root.revisionId ||
                page.revisionNumber != root.revisionNumber ||
                page.sourceKind != root.sourceKind ||
                page.name != root.name ||
                page.notes != root.notes ||
                page.durationWeeks != root.durationWeeks ||
                page.startsOn != root.startsOn ||
                page.acceptedAt != root.acceptedAt))) {
      throw const FormatException('Revision is not the accepted snapshot');
    }
  }

  Future<CoachProgramRevisionAcceptanceResult> accept({
    required String assignmentId,
    required String revisionId,
  }) async {
    final raw = await client.rpc(
      'stk_accept_program_revision',
      params: {
        'p_assignment_id': assignmentId,
        'p_revision_id': revisionId,
      },
    );
    if (raw is! Map) {
      throw const FormatException('Invalid revision acceptance response');
    }
    final json = Map<String, dynamic>.from(raw);
    final acceptedAt = DateTime.tryParse('${json['accepted_at']}');
    if (json['assignment_id'] != assignmentId ||
        json['revision_id'] != revisionId ||
        !_positiveInt(json['revision_number'], max: 10000) ||
        acceptedAt == null ||
        json['already_accepted'] is! bool ||
        !_positiveInt(json['current_assignment_version'], max: 10000)) {
      throw const FormatException('Invalid revision acceptance scope');
    }
    return CoachProgramRevisionAcceptanceResult(
      assignmentId: assignmentId,
      revisionId: revisionId,
      revisionNumber: json['revision_number'] as int,
      acceptedAt: acceptedAt,
      alreadyAccepted: json['already_accepted'] as bool,
      currentAssignmentVersion: json['current_assignment_version'] as int,
    );
  }

  static AssignedProgramStatus _status(String? value) {
    for (final status in AssignedProgramStatus.values) {
      if (status.name == value) return status;
    }
    throw const FormatException('Invalid assignment status');
  }

  static String? _optionalNonEmptyString(Object? value) {
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw const FormatException('Invalid optional id');
    }
    return value;
  }

  static int? _optionalPositiveInt(Object? value, {required int max}) {
    if (value == null) return null;
    if (!_positiveInt(value, max: max)) {
      throw const FormatException('Invalid optional integer');
    }
    return value as int;
  }

  static DateTime? _optionalDate(Object? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) {
      throw const FormatException('Invalid optional date');
    }
    return parsed;
  }

  static bool _positiveInt(Object? value, {required int max}) =>
      value is int && value > 0 && value <= max;

  static bool _nonNegativeInt(Object? value, {required int max}) =>
      value is int && value >= 0 && value <= max;
}
