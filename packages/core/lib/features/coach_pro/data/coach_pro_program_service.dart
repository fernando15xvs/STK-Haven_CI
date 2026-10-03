import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CoachProProgramQuery = ({String relationshipId, String assignmentId,
  int version, String? routineId, int offset});

class CoachProRoutineSummary {
  final String id;
  final String name;
  final int position;
  const CoachProRoutineSummary(this.id, this.name, this.position);
}

class CoachProProgramPage {
  final String name;
  final int version;
  final AssignedProgramStatus status;
  final String? routineName;
  final int totalCount;
  final List<CoachProRoutineSummary> routines;
  final List<AssignedExerciseSnapshot> exercises;
  const CoachProProgramPage({required this.name, required this.version,
    required this.status, required this.totalCount, this.routineName,
    this.routines = const [], this.exercises = const []});
}

class CoachProProgramService {
  final SupabaseClient client;
  const CoachProProgramService(this.client);

  Future<CoachProProgramPage> load(CoachProProgramQuery query) async {
    final raw = await client.rpc('stk_get_coach_pro_program_page', params: {
      'p_relationship_id': query.relationshipId, 'p_assignment_id': query.assignmentId,
      'p_version': query.version, 'p_routine_id': query.routineId,
      'p_limit': 25, 'p_offset': query.offset,
    });
    if (raw is! Map) throw const FormatException('Invalid program page');
    final json = Map<String, dynamic>.from(raw);
    final statuses = AssignedProgramStatus.values.where((s) => s.name == json['status']);
    final routine = json['routine'];
    if (json['assignment_id'] != query.assignmentId ||
        json['relationship_id'] != query.relationshipId || json['version'] != query.version ||
        '${json['name'] ?? ''}'.trim().isEmpty || statuses.isEmpty ||
        json['total_count'] is! int || (json['total_count'] as int) < 0 ||
        json['items'] is! List ||
        (query.routineId == null ? routine != null
            : routine is! Map || routine['id'] != query.routineId)) {
      throw const FormatException('Invalid program scope');
    }
    final routines = <CoachProRoutineSummary>[];
    final exercises = <AssignedExerciseSnapshot>[];
    for (final item in json['items'] as List) {
      final row = Map<String, dynamic>.from(item as Map);
      if ('${row['id'] ?? ''}'.isEmpty || '${row['name'] ?? ''}'.trim().isEmpty ||
          row['position'] is! int) throw const FormatException('Invalid program item');
      if (query.routineId == null) {
        routines.add(CoachProRoutineSummary(row['id'] as String,
            row['name'] as String, row['position'] as int));
      } else {
        for (final key in ['target_sets','target_reps_min','target_reps_max',
          'rest_seconds','warmup_sets','approach_sets']) {
          if (row[key] is! num) throw const FormatException('Invalid exercise prescription');
        }
        exercises.add(AssignedExerciseSnapshot.fromJson(row));
      }
    }
    return CoachProProgramPage(name: json['name'] as String, version: query.version,
      status: statuses.single, routineName: routine is Map ? routine['name'] as String : null,
      totalCount: json['total_count'] as int, routines: List.unmodifiable(routines),
      exercises: List.unmodifiable(exercises));
  }
}
