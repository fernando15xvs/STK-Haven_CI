import 'package:core/features/coach_pro/domain/coach_pro_template.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// RPCs re-check subscription, coach ownership and client consent per request.
class CoachProTemplateService {
  final SupabaseClient client;
  const CoachProTemplateService(this.client);

  Future<CoachProTemplatePage> list({int offset = 0}) async {
    if (offset < 0 || offset > 10000) throw ArgumentError.value(offset, 'offset');
    final raw = await client.rpc('stk_list_coach_pro_templates',
        params: {'p_limit': 25, 'p_offset': offset});
    if (raw is! Map) throw const FormatException('Invalid template page');
    return CoachProTemplatePage.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<String> saveFromRevision({
    required String relationshipId,
    required String assignmentId,
    required String revisionId,
    required String title,
  }) async {
    final clean = title.trim();
    if (clean.isEmpty || clean.runes.length > 120) {
      throw ArgumentError.value(title, 'title', '1–120 characters');
    }
    final raw = await client.rpc('stk_save_coach_pro_template_from_revision',
        params: {
          'p_relationship_id': relationshipId,
          'p_assignment_id': assignmentId,
          'p_revision_id': revisionId,
          'p_title': clean,
        });
    if (raw is! String || raw.isEmpty) {
      throw const FormatException('Invalid saved template identifier');
    }
    return raw;
  }

  Future<String> assign({
    required String templateId,
    required String relationshipId,
  }) async {
    final raw = await client.rpc('stk_assign_coach_pro_template',
        params: {'p_template_id': templateId, 'p_relationship_id': relationshipId});
    if (raw is! String || raw.isEmpty) {
      throw const FormatException('Invalid assigned program identifier');
    }
    return raw;
  }

  Future<void> archive(String templateId) async {
    final result = await client.rpc('stk_archive_coach_pro_template',
        params: {'p_template_id': templateId});
    if (result != true) throw StateError('Template unavailable');
  }
}
