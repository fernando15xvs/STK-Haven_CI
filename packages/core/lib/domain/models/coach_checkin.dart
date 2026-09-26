class CoachCheckin {
  final String id, relationshipId, coachUserId, clientUserId, note;
  final int energy, recovery;
  final DateTime createdAt;
  const CoachCheckin({required this.id, required this.relationshipId, required this.coachUserId, required this.clientUserId, required this.energy, required this.recovery, required this.note, required this.createdAt});
  factory CoachCheckin.fromJson(Map<String,dynamic> j)=>CoachCheckin(
    id:'${j['id']??''}', relationshipId:'${j['relationship_id']??''}', coachUserId:'${j['coach_user_id']??''}',
    clientUserId:'${j['client_user_id']??''}', energy:(j['energy'] as num?)?.toInt()??0,
    recovery:(j['recovery'] as num?)?.toInt()??0, note:'${j['note']??''}',
    createdAt:DateTime.tryParse('${j['created_at']}')??DateTime.now());
}
class CoachCheckinComment {
  final String id, checkinId, authorUserId, body;
  final DateTime createdAt;
  const CoachCheckinComment({required this.id,required this.checkinId,required this.authorUserId,required this.body,required this.createdAt});
  factory CoachCheckinComment.fromJson(Map<String,dynamic> j)=>CoachCheckinComment(
    id:'${j['id']??''}',checkinId:'${j['checkin_id']??''}',authorUserId:'${j['author_user_id']??''}',
    body:'${j['body']??''}',createdAt:DateTime.tryParse('${j['created_at']}')??DateTime.now());
}
