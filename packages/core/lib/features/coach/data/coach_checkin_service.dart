import 'package:core/domain/models/coach_checkin.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class CoachCheckinService {
  final SupabaseClient client;
  const CoachCheckinService(this.client);
  Future<String> create({required String relationshipId,required int energy,required int recovery,String note=''}) async {
    final r=await client.rpc('stk_create_coach_checkin',params:{'p_relationship_id':relationshipId,'p_energy':energy,'p_recovery':recovery,'p_note':note});
    return r.toString();
  }
  Future<List<CoachCheckin>> list(String clientUserId) async {
    final r=await client.rpc('stk_list_coach_checkins',params:{'p_client_user_id':clientUserId});
    return r is List ? r.whereType<Map>().map((e)=>CoachCheckin.fromJson(Map<String,dynamic>.from(e))).toList(growable:false) : const [];
  }
  Future<void> comment(String checkinId,String body)=>client.rpc('stk_add_coach_checkin_comment',params:{'p_checkin_id':checkinId,'p_body':body});
  Future<List<CoachCheckinComment>> comments(String checkinId) async {
    final r=await client.rpc('stk_list_coach_checkin_comments',params:{'p_checkin_id':checkinId});
    return r is List ? r.whereType<Map>().map((e)=>CoachCheckinComment.fromJson(Map<String,dynamic>.from(e))).toList(growable:false) : const [];
  }
}
