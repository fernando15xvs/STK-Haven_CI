import 'package:core/domain/models/coach_relationship.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachClientService {
  final SupabaseClient client;

  const CoachClientService(this.client);

  Future<String> createInvitation({
    required Set<CoachPermission> permissions,
    int expiresInHours = 168,
  }) async {
    final response = await client.rpc(
      'stk_create_coach_invitation',
      params: <String, dynamic>{
        'p_permissions': coachPermissionsToJson(permissions),
        'p_expires_in_hours': expiresInHours,
      },
    );
    final code = response?.toString().trim() ?? '';
    if (code.isEmpty) {
      throw const FormatException('Invitation code was empty.');
    }
    return code;
  }

  Future<CoachInvitationPreview?> previewInvitation(String code) async {
    final response = await client.rpc(
      'stk_preview_coach_invitation',
      params: <String, dynamic>{'p_code': code.trim()},
    );

    if (response is List && response.isNotEmpty) {
      final raw = response.first;
      if (raw is Map) {
        return CoachInvitationPreview.fromJson(
          Map<String, dynamic>.from(raw),
        );
      }
    }
    return null;
  }

  Future<String> acceptInvitation(String code) async {
    final response = await client.rpc(
      'stk_accept_coach_invitation',
      params: <String, dynamic>{'p_code': code.trim()},
    );
    final relationshipId = response?.toString().trim() ?? '';
    if (relationshipId.isEmpty) {
      throw const FormatException('Relationship id was empty.');
    }
    return relationshipId;
  }

  Future<void> setPermissions({
    required String relationshipId,
    required Set<CoachPermission> permissions,
  }) async {
    await client.rpc(
      'stk_set_coach_permissions',
      params: <String, dynamic>{
        'p_relationship_id': relationshipId,
        'p_permissions': coachPermissionsToJson(permissions),
      },
    );
  }

  Future<void> revokeRelationship(String relationshipId) async {
    await client.rpc(
      'stk_revoke_coach_relationship',
      params: <String, dynamic>{
        'p_relationship_id': relationshipId,
      },
    );
  }

  Future<List<CoachClientRelationship>> getRelationships() async {
    final response = await client.rpc('stk_list_my_coach_relationships');
    if (response is! List) {
      return const <CoachClientRelationship>[];
    }

    return response
        .whereType<Map>()
        .map(
          (row) => CoachClientRelationship.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .where(
          (relationship) =>
              relationship.id.isNotEmpty &&
              relationship.coachUserId.isNotEmpty &&
              relationship.clientUserId.isNotEmpty,
        )
        .toList(growable: false);
  }
}
