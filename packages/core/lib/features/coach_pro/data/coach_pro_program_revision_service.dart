import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:core/features/coach_pro/domain/coach_pro_program_revision.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CoachProProgramRevisionHistoryQuery = ({
  String relationshipId,
  String assignmentId,
  int offset,
});

typedef CoachProProgramRevisionDetailQuery = ({
  String relationshipId,
  String assignmentId,
  String revisionId,
  String? routineId,
  int offset,
});

class CoachProProgramRevisionService {
  static const int pageSize = 25;

  final SupabaseClient client;
  const CoachProProgramRevisionService(this.client);

  Future<CoachProProgramRevisionHistoryResult> list(
    CoachProProgramRevisionHistoryQuery query,
  ) async {
    final raw = await client.rpc(
      'stk_list_coach_pro_program_revisions',
      params: {
        'p_relationship_id': query.relationshipId,
        'p_assignment_id': query.assignmentId,
        'p_limit': pageSize,
        'p_offset': query.offset,
      },
    );
    if (raw is! Map) {
      throw const FormatException('Invalid revision history page');
    }
    final json = Map<String, dynamic>.from(raw);
    if (json['assignment_id'] != query.assignmentId ||
        json['relationship_id'] != query.relationshipId ||
        !_positiveInt(json['current_assignment_version'], max: 10000) ||
        !_nonNegativeInt(json['total_count'], max: 10000) ||
        json['items'] is! List) {
      throw const FormatException('Invalid revision history scope');
    }

    final totalCount = json['total_count'] as int;
    final items = <CoachProProgramRevisionSummary>[];
    for (final value in json['items'] as List) {
      if (value is! Map) {
        throw const FormatException('Invalid revision history item');
      }
      items.add(_parseSummary(Map<String, dynamic>.from(value)));
    }
    if (items.length > pageSize || items.length > totalCount) {
      throw const FormatException('Invalid revision history count');
    }

    return CoachProProgramRevisionHistoryResult(
      assignmentId: query.assignmentId,
      relationshipId: query.relationshipId,
      currentAssignmentVersion: json['current_assignment_version'] as int,
      totalCount: totalCount,
      items: List.unmodifiable(items),
    );
  }

  Future<CoachProProgramRevisionPage> load(
    CoachProProgramRevisionDetailQuery query,
  ) async {
    final raw = await client.rpc(
      'stk_get_coach_pro_program_revision_page',
      params: {
        'p_relationship_id': query.relationshipId,
        'p_assignment_id': query.assignmentId,
        'p_revision_id': query.revisionId,
        'p_revision_routine_id': query.routineId,
        'p_limit': pageSize,
        'p_offset': query.offset,
      },
    );
    if (raw is! Map) {
      throw const FormatException('Invalid revision detail page');
    }
    final json = Map<String, dynamic>.from(raw);
    final routine = json['routine'];
    if (json['assignment_id'] != query.assignmentId ||
        json['relationship_id'] != query.relationshipId ||
        json['revision_id'] != query.revisionId ||
        json['revision_id'] is! String ||
        !_positiveInt(json['revision_number'], max: 10000) ||
        !_positiveInt(json['observed_assignment_version'], max: 10000) ||
        json['name'] is! String ||
        (json['name'] as String).trim().isEmpty ||
        (json['name'] as String).runes.length > 120 ||
        !_positiveInt(json['duration_weeks'], max: 104) ||
        json['training_weekdays'] is! List ||
        DateTime.tryParse('${json['starts_on']}') == null ||
        DateTime.tryParse('${json['recorded_at']}') == null ||
        !_nonNegativeInt(json['total_count'], max: 10000) ||
        json['items'] is! List ||
        (query.routineId == null
            ? routine != null
            : routine is! Map ||
                routine['id'] is! String ||
                routine['id'] != query.routineId ||
                routine['name'] is! String ||
                (routine['name'] as String).trim().isEmpty ||
                routine['position'] is! int ||
                (routine['position'] as int) < 0)) {
      throw const FormatException('Invalid revision detail scope');
    }

    final source = CoachProProgramRevisionSource.parse(
      json['source_kind']?.toString(),
    );
    final authoredAt = json['authored_at'] == null
        ? null
        : DateTime.tryParse('${json['authored_at']}');
    if ((json['authored_at'] != null && authoredAt == null) ||
        (source == CoachProProgramRevisionSource.legacyBaseline &&
            authoredAt != null) ||
        (source == CoachProProgramRevisionSource.coachRevision &&
            authoredAt == null)) {
      throw const FormatException('Invalid revision authorship');
    }

    if (json['previous_revision_id'] != null &&
        (json['previous_revision_id'] is! String ||
            (json['previous_revision_id'] as String).isEmpty)) {
      throw const FormatException('Invalid previous revision');
    }
    final previousRevisionId = json['previous_revision_id'] as String?;
    if (previousRevisionId != null && previousRevisionId.isEmpty) {
      throw const FormatException('Invalid previous revision');
    }

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
    if (weekdays.length > 7) {
      throw const FormatException('Invalid revision weekdays');
    }

    final routines = <CoachProProgramRevisionRoutineSummary>[];
    final exercises = <AssignedExerciseSnapshot>[];
    for (final value in json['items'] as List) {
      if (value is! Map) {
        throw const FormatException('Invalid revision detail item');
      }
      final row = Map<String, dynamic>.from(value);
      if (row['id'] is! String ||
          (row['id'] as String).isEmpty ||
          row['name'] is! String ||
          (row['name'] as String).trim().isEmpty ||
          row['position'] is! int ||
          (row['position'] as int) < 0) {
        throw const FormatException('Invalid revision detail item');
      }
      if (query.routineId == null) {
        routines.add(
          CoachProProgramRevisionRoutineSummary(
            id: row['id'] as String,
            name: row['name'] as String,
            position: row['position'] as int,
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
      throw const FormatException('Invalid revision detail count');
    }

    return CoachProProgramRevisionPage(
      assignmentId: query.assignmentId,
      relationshipId: query.relationshipId,
      revisionId: query.revisionId,
      revisionNumber: json['revision_number'] as int,
      previousRevisionId: previousRevisionId,
      source: source,
      observedAssignmentVersion: json['observed_assignment_version'] as int,
      name: (json['name'] as String).trim(),
      durationWeeks: json['duration_weeks'] as int,
      trainingWeekdays: Set.unmodifiable(weekdays),
      startsOn: DateTime.parse('${json['starts_on']}'),
      recordedAt: DateTime.parse('${json['recorded_at']}'),
      authoredAt: authoredAt,
      routineName:
          routine is Map ? (routine['name'] as String).trim() : null,
      totalCount: totalCount,
      routines: List.unmodifiable(routines),
      exercises: List.unmodifiable(exercises),
    );
  }

  CoachProProgramRevisionSummary _parseSummary(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        !_positiveInt(json['revision_number'], max: 10000) ||
        !_positiveInt(json['observed_assignment_version'], max: 10000) ||
        DateTime.tryParse('${json['recorded_at']}') == null) {
      throw const FormatException('Invalid revision history item');
    }

    final source = CoachProProgramRevisionSource.parse(
      json['source_kind']?.toString(),
    );
    final authoredAt = json['authored_at'] == null
        ? null
        : DateTime.tryParse('${json['authored_at']}');
    if ((json['authored_at'] != null && authoredAt == null) ||
        (source == CoachProProgramRevisionSource.legacyBaseline &&
            authoredAt != null) ||
        (source == CoachProProgramRevisionSource.coachRevision &&
            authoredAt == null)) {
      throw const FormatException('Invalid revision authorship');
    }

    if (json['previous_revision_id'] != null &&
        (json['previous_revision_id'] is! String ||
            (json['previous_revision_id'] as String).isEmpty)) {
      throw const FormatException('Invalid previous revision');
    }
    final previousRevisionId = json['previous_revision_id'] as String?;
    if (previousRevisionId != null && previousRevisionId.isEmpty) {
      throw const FormatException('Invalid previous revision');
    }

    return CoachProProgramRevisionSummary(
      id: json['id'] as String,
      revisionNumber: json['revision_number'] as int,
      previousRevisionId: previousRevisionId,
      source: source,
      observedAssignmentVersion: json['observed_assignment_version'] as int,
      recordedAt: DateTime.parse('${json['recorded_at']}'),
      authoredAt: authoredAt,
    );
  }

  static bool _positiveInt(dynamic value, {required int max}) =>
      value is int && value > 0 && value <= max;

  static bool _nonNegativeInt(dynamic value, {required int max}) =>
      value is int && value >= 0 && value <= max;
}
