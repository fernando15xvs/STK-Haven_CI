import 'package:core/domain/models/coach_checkin.dart';
import 'package:core/features/coach/data/coach_checkin_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class CoachCheckinState {
  final List<CoachCheckin> items; final Map<String,List<CoachCheckinComment>> comments; final bool busy; final String? message;
  const CoachCheckinState({this.items=const [],this.comments=const {},this.busy=false,this.message});
  CoachCheckinState copyWith({List<CoachCheckin>? items,Map<String,List<CoachCheckinComment>>? comments,bool? busy,String? message,bool clear=false})=>
    CoachCheckinState(items:items??this.items,comments:comments??this.comments,busy:busy??this.busy,message:clear?null:(message??this.message));
}
final coachCheckinServiceProvider=Provider((ref)=>CoachCheckinService(Supabase.instance.client));
final coachCheckinProvider=NotifierProvider<CoachCheckinNotifier,CoachCheckinState>(CoachCheckinNotifier.new);
class CoachCheckinNotifier extends Notifier<CoachCheckinState>{
  late final CoachCheckinService _service;
  @override CoachCheckinState build(){_service=ref.watch(coachCheckinServiceProvider);return const CoachCheckinState();}
  Future<void> load(String client) async { if(state.busy)return; state=state.copyWith(busy:true,clear:true); try{state=state.copyWith(items:await _service.list(client),busy:false);}catch(_){state=state.copyWith(busy:false,message:'No se pudieron cargar los check-ins.');}}
  Future<bool> create({required String relationshipId,required String clientUserId,required int energy,required int recovery,String note=''}) async {
    if(state.busy)return false; state=state.copyWith(busy:true,clear:true); try{await _service.create(relationshipId:relationshipId,energy:energy,recovery:recovery,note:note);state=state.copyWith(busy:false,message:'Check-in guardado.');await load(clientUserId);return true;}catch(_){state=state.copyWith(busy:false,message:'No se pudo guardar el check-in.');return false;}
  }
  Future<void> loadComments(String id) async {try{final v=await _service.comments(id);final m=Map<String,List<CoachCheckinComment>>.from(state.comments)..[id]=v;state=state.copyWith(comments:Map.unmodifiable(m));}catch(_){}}
  Future<bool> addComment(String id,String body) async {try{await _service.comment(id,body);await loadComments(id);return true;}catch(_){state=state.copyWith(message:'No se pudo enviar el comentario.');return false;}}
}
