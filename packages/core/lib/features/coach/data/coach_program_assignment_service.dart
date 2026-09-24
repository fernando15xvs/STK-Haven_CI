import 'package:core/domain/models/coach_program_assignment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachProgramAssignmentService {
  final SupabaseClient client;

  const CoachProgramAssignmentService(this.client);

  Future<String> assignProgram({
    required String clientUserId,
    required Map<String, dynamic> programPayload,
  }) async {
    final response = await client.rpc(
      'stk_assign_program',
      params: <String, dynamic>{
        'p_client_user_id': clientUserId,
        'p_program': programPayload,
      },
    );
    final id = response?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw const FormatException('Assigned program id was empty.');
    }
    return id;
  }

  Future<List<CoachProgramAssignmentSummary>> listAssignments() async {
    final response = await client.rpc('stk_list_my_assigned_programs');
    if (response is! List) {
      return const <CoachProgramAssignmentSummary>[];
    }

    return response
        .whereType<Map>()
        .map(
          (row) => CoachProgramAssignmentSummary.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .where(
          (item) =>
              item.id.isNotEmpty &&
              item.coachUserId.isNotEmpty &&
              item.clientUserId.isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<CoachProgramAssignment> getAssignment(String assignmentId) async {
    final response = await client.rpc(
      'stk_get_assigned_program',
      params: <String, dynamic>{
        'p_assignment_id': assignmentId,
      },
    );
    if (response is! Map) {
      throw const FormatException('Assigned program payload was invalid.');
    }

    return CoachProgramAssignment.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> acceptAssignment(String assignmentId) async {
    await client.rpc(
      'stk_accept_assigned_program',
      params: <String, dynamic>{
        'p_assignment_id': assignmentId,
      },
    );
  }

  Future<void> archiveAssignment(String assignmentId) async {
    await client.rpc(
      'stk_archive_assigned_program',
      params: <String, dynamic>{
        'p_assignment_id': assignmentId,
      },
    );
  }
}
