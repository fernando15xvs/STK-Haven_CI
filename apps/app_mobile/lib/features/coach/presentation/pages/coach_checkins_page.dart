import 'package:gym_tracker/core/layout/mobile_content_frame.dart';
import 'package:gym_tracker/features/coach_pro/presentation/coach_pro_checkin_cadence_page.dart';
import 'package:gym_tracker/features/coach_pro/presentation/coach_pro_reminder_settings_page.dart';
import 'package:core/domain/models/coach_checkin.dart';
import 'package:core/features/coach/application/coach_checkin_provider.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachCheckinsPage extends ConsumerStatefulWidget {
  final String relationshipId, clientUserId, clientDisplayName;
  final bool isClient, canComment, canCreate;
  const CoachCheckinsPage({super.key,required this.relationshipId,required this.clientUserId,required this.clientDisplayName,required this.isClient,required this.canComment,this.canCreate=true});
  @override ConsumerState<CoachCheckinsPage> createState()=>_CoachCheckinsPageState();
}
class _CoachCheckinsPageState extends ConsumerState<CoachCheckinsPage>{
  bool loaded=false;
  late final String? _viewerId;
  @override void initState(){super.initState();_viewerId=ref.read(appIdentityProvider).userId;}
  @override Widget build(BuildContext context){
    final identity=ref.watch(appIdentityProvider);
    if(!identity.signedIn||identity.userId!=_viewerId)return Scaffold(appBar:AppBar(title:const Text('Check-ins')),body:const Center(child:Text('La sesión cambió. Vuelve a Coach.')));
    final s=ref.watch(coachCheckinProvider);
    final items=s.items.where((item)=>item.relationshipId==widget.relationshipId).toList(growable:false);
    if(!loaded){loaded=true;WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)ref.read(coachCheckinProvider.notifier).load(widget.clientUserId,relationshipId:widget.relationshipId);});}
    ref.listen(coachCheckinProvider,(p,n){if(n.message!=null&&n.message!=p?.message)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(n.message!)));});
    return Scaffold(
      appBar:AppBar(title:Text('Check-ins · ${widget.clientDisplayName}')),
      floatingActionButton:widget.isClient&&widget.canCreate?FloatingActionButton.extended(onPressed:s.busy?null:_create,icon:const Icon(Icons.add_rounded),label:const Text('Nuevo check-in')):null,
      body:RefreshIndicator(onRefresh:()=>ref.read(coachCheckinProvider.notifier).load(widget.clientUserId,relationshipId:widget.relationshipId),child:ListView(
        physics:const AlwaysScrollableScrollPhysics(),padding:SecondaryScreenInsets.scrollPadding(context, const EdgeInsets.fromLTRB(20,20,20,100)),children:[
          const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('Registro breve de energía y recuperación percibidas. No es una evaluación médica ni genera diagnósticos.'))),
          if (widget.isClient && widget.canCreate)
            Align(alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event_repeat_outlined),
                label: const Text('Frecuencia propuesta'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) =>
                    CoachProCheckinCadencePage(
                      relationshipId: widget.relationshipId,
                      asCoach: false,
                    )),
                ),
              ),
            ),
          if (widget.isClient && widget.canCreate)
            Align(alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Recordatorios voluntarios'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) =>
                    CoachProReminderSettingsPage(
                      relationshipId: widget.relationshipId,
                    )),
                ),
              ),
            ),
          const SizedBox(height:12),
          if(s.busy&&items.isEmpty)const Center(child:CircularProgressIndicator())
          else if(items.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('Todavía no hay check-ins compartidos.')))
          else for(final item in items)Card(child:ListTile(
            leading:CircleAvatar(child:Text('${item.energy}')),
            title:Text('Energía ${item.energy}/5 · Recuperación ${item.recovery}/5'),
            subtitle:Text([_date(item.createdAt),if(item.note.trim().isNotEmpty)item.note].join('\n')),
            trailing:const Icon(Icons.chat_bubble_outline),
            onTap:()=>_comments(item),
          )),
        ],
      )),
    );
  }
  Future<void> _create()async{
    var energy=3,recovery=3;final note=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(context,setState)=>AlertDialog(
      title:const Text('Nuevo check-in'),content:SizedBox(width:480,child:Column(mainAxisSize:MainAxisSize.min,children:[
        _Score(label:'Energía percibida',value:energy,onChanged:(v)=>setState(()=>energy=v)),
        _Score(label:'Recuperación percibida',value:recovery,onChanged:(v)=>setState(()=>recovery=v)),
        TextField(controller:note,maxLength:2000,maxLines:3,decoration:const InputDecoration(labelText:'Nota opcional')),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Guardar'))],
    )));
    if(ok==true&&mounted&&ref.read(appIdentityProvider).userId==_viewerId)await ref.read(coachCheckinProvider.notifier).create(relationshipId:widget.relationshipId,clientUserId:widget.clientUserId,energy:energy,recovery:recovery,note:note.text);
    note.dispose();
  }
  Future<void> _comments(CoachCheckin item)async{
    await ref.read(coachCheckinProvider.notifier).loadComments(item.id);if(!mounted||ref.read(appIdentityProvider).userId!=_viewerId)return;
    final ctl=TextEditingController();
    await showDialog<void>(context:context,builder:(d)=>Consumer(builder:(context,ref,_){
      final comments=ref.watch(coachCheckinProvider).comments[item.id]??const <CoachCheckinComment>[];
      final me=ref.watch(appIdentityProvider).userId;
      if(me!=_viewerId)return AlertDialog(content:const Text('La sesión cambió.'),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cerrar'))]);
      return AlertDialog(title:const Text('Comentarios'),content:SizedBox(width:520,height:360,child:Column(children:[
        Expanded(child:comments.isEmpty?const Center(child:Text('Sin comentarios.')):ListView(children:[for(final c in comments)ListTile(title:Text(c.authorUserId==me?'Tú':'Persona vinculada'),subtitle:Text(c.body))])),
        if(widget.canComment)TextField(controller:ctl,maxLength:2000,decoration:const InputDecoration(labelText:'Comentario')),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cerrar')),if(widget.canComment)FilledButton(onPressed:()async{if(ctl.text.trim().isEmpty)return;if(await ref.read(coachCheckinProvider.notifier).addComment(item.id,ctl.text))ctl.clear();},child:const Text('Enviar'))]);
    }));ctl.dispose();
  }
}
class _Score extends StatelessWidget{
  final String label;final int value;final ValueChanged<int> onChanged;
  const _Score({required this.label,required this.value,required this.onChanged});
  @override Widget build(BuildContext context)=>Row(children:[Expanded(child:Text(label)),DropdownButton<int>(value:value,items:[for(var i=1;i<=5;i++)DropdownMenuItem(value:i,child:Text('$i / 5'))],onChanged:(v){if(v!=null)onChanged(v);})]);
}
String _date(DateTime v){final x=v.toLocal();return '${x.day.toString().padLeft(2,'0')}/${x.month.toString().padLeft(2,'0')}/${x.year}';}
