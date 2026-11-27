import 'package:gym_tracker/core/layout/mobile_content_frame.dart';
import 'package:core/domain/models/coach_relationship.dart';
import 'package:core/features/coach/application/coach_client_provider.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:gym_tracker/features/coach/presentation/pages/coach_client_progress_page.dart';
import 'package:gym_tracker/features/coach/presentation/pages/coach_checkins_page.dart';
import 'package:gym_tracker/features/coach/presentation/pages/coach_program_assignments_page.dart';
import 'package:gym_tracker/features/coach/presentation/pages/coach_tasks_page.dart';
import 'package:gym_tracker/features/coach/presentation/pages/coach_measurement_page.dart';
import 'package:gym_tracker/features/nutrition/presentation/pages/coach_nutrition_guidance_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One compact relationship workspace. All data pages still authorize via RPC.
class CoachClientDetailPage extends ConsumerStatefulWidget {
  final String relationshipId;
  const CoachClientDetailPage({super.key,required this.relationshipId});
  @override ConsumerState<CoachClientDetailPage> createState()=>_CoachClientDetailPageState();
}
class _CoachClientDetailPageState extends ConsumerState<CoachClientDetailPage> with WidgetsBindingObserver {
  late final String? _viewerId;
  @override void initState(){
    super.initState();
    _viewerId=ref.read(appIdentityProvider).userId;
    WidgetsBinding.instance.addObserver(this);
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed&&mounted)_refresh();
  }
  Future<void> _refresh() async {
    if(ref.read(appIdentityProvider).userId==_viewerId)
      await ref.read(coachClientProvider.notifier).refreshRelationships();
  }
  Future<void> _open(Widget page) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder:(_)=>page));
    if(mounted)await _refresh();
  }
  @override Widget build(BuildContext context){
    final identity=ref.watch(appIdentityProvider);
    final state=ref.watch(coachClientProvider);
    CoachClientRelationship? current;
    for(final item in state.relationships){
      if(item.id==widget.relationshipId&&(item.isClient(identity.userId)||item.isCoach(identity.userId))){current=item;break;}
    }
    if(!identity.signedIn||identity.userId==null||identity.userId!=_viewerId||current==null){
      return Scaffold(appBar:AppBar(title:const Text('Mi Coach')),body:Center(child:Padding(
        padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
          if(state.busy)const CircularProgressIndicator() else ...[
            const Text('La relación no está disponible en esta sesión.',textAlign:TextAlign.center),
            TextButton(onPressed:_refresh,child:const Text('Actualizar')),
          ],
        ]))));
    }
    final relationship=current;
    final userId=identity.userId!;
    final asCoach=relationship.isCoach(userId);
    final name=relationship.counterpartDisplayName?.trim();
    final displayName=name!=null&&name.isNotEmpty?name:(asCoach?'Cliente vinculado':'Entrenador vinculado');
    bool can(CoachPermission p)=>relationship.allows(p);
    return Scaffold(appBar:AppBar(title:Text(asCoach?'Cliente':'Mi entrenador'),actions:[
      IconButton(tooltip:'Actualizar',onPressed:state.busy?null:_refresh,icon:const Icon(Icons.refresh)),
    ]),body:SafeArea(bottom: false, child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:820),
      child:RefreshIndicator(onRefresh:_refresh,child:ListView(physics:const AlwaysScrollableScrollPhysics(),
        padding:SecondaryScreenInsets.scrollPadding(context, const EdgeInsets.fromLTRB(20,20,20,80)),children:[
          Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
            CircleAvatar(radius:27,child:Icon(asCoach?Icons.person_outline:Icons.sports_outlined)),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(displayName,style:Theme.of(context).textTheme.titleLarge),
              Text(switch(relationship.status){CoachRelationshipStatus.active=>'Relación activa',CoachRelationshipStatus.paused=>'Relación pausada',CoachRelationshipStatus.revoked=>'Acceso revocado'}),
            ])),
          ]))),
          const SizedBox(height:20),
          Text(asCoach?'Herramientas del cliente':'Tu plan y seguimiento',style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:10),
          Card(child:Column(children:[
            _tile(Icons.fitness_center_outlined,'Programas asignados',asCoach?'Asignar y revisar programas':'Recibidos, revisiones e instalación',
              !asCoach||can(CoachPermission.assignPrograms),()=>_open(CoachProgramAssignmentsPage(clientUserId:relationship.clientUserId,clientDisplayName:displayName,
                relationshipId:relationship.id,canAssign:asCoach&&can(CoachPermission.assignPrograms)))),
            const Divider(height:1),
            _tile(Icons.task_alt_outlined,'Tareas',asCoach?'Asignaciones y adherencia':'Pendientes, historial y comentarios',
              !asCoach||can(CoachPermission.assignTasks),()=>_open(CoachTasksPage(clientUserId:relationship.clientUserId,clientDisplayName:displayName,
                relationshipId:relationship.id,canAssign:asCoach&&can(CoachPermission.assignTasks),canComment:relationship.isActive&&(!asCoach||can(CoachPermission.comment))))),
            const Divider(height:1),
            _tile(Icons.fact_check_outlined,'Check-ins','Energía y recuperación percibidas',!asCoach||can(CoachPermission.viewCheckins),
              ()=>_open(CoachCheckinsPage(relationshipId:relationship.id,clientUserId:relationship.clientUserId,clientDisplayName:displayName,
                isClient:!asCoach,canCreate:!asCoach&&can(CoachPermission.viewCheckins),canComment:relationship.isActive&&(!asCoach||can(CoachPermission.comment))))),
            const Divider(height:1),
            _tile(Icons.restaurant_menu_outlined,'Orientación alimentaria','Guías y versiones compartidas',!asCoach||can(CoachPermission.viewNutrition),
              ()=>_open(CoachNutritionGuidancePage(clientUserId:relationship.clientUserId,clientDisplayName:displayName,relationshipId:relationship.id,canEdit:asCoach&&can(CoachPermission.viewNutrition)))),
            const Divider(height:1),
            _tile(Icons.insights_outlined,'Progreso compartido','Resumen sincronizado y sugerencias STK',!asCoach||can(CoachPermission.viewProgress),
              ()=>_open(CoachClientProgressPage(clientUserId:relationship.clientUserId,clientDisplayName:displayName))),
            const Divider(height:1),
            _tile(Icons.monitor_weight_outlined,'Medidas compartidas',asCoach?'Solo campos autorizados':'Elige qué campos compartir o retirar',can(CoachPermission.viewMeasurements),
              ()=>_open(CoachMeasurementPage(relationshipId:relationship.id,clientUserId:relationship.clientUserId,viewerUserId:userId))),
          ])),
          const SizedBox(height:16),
          Card(child:ExpansionTile(leading:const Icon(Icons.shield_outlined),title:const Text('Permisos y privacidad'),
            subtitle:Text('${relationship.isActive?relationship.permissions.length:0} permisos vigentes'),
            children:[
              for(final permission in CoachPermission.values)ListTile(
                dense:true,title:Text(_permissionLabel(permission)),
                leading:Icon(can(permission)?Icons.check_circle_outline:Icons.lock_outline),
                subtitle:Text(can(permission)?'Permitido':'No permitido')),
              if(!asCoach&&relationship.isActive)Padding(padding:const EdgeInsets.all(12),
                child:FilledButton.tonal(onPressed:state.busy?null:()=>_edit(relationship),child:const Text('Editar permisos'))),
              if(relationship.isActive)Padding(padding:const EdgeInsets.all(12),
                child:TextButton(onPressed:state.busy?null:()=>_revoke(relationship),child:const Text('Revocar relación'))),
            ],
          )),
          const SizedBox(height:12),
          Text('Los permisos los controla el cliente. Los programas y registros personales no se borran al desvincular.',style:Theme.of(context).textTheme.bodySmall),
        ]))))));
  }
  Widget _tile(IconData icon,String title,String subtitle,bool allowed,VoidCallback open)=>ListTile(
    enabled:allowed,leading:Icon(icon),title:Text(title),subtitle:Text(allowed?subtitle:'Sin permiso vigente'),
    trailing:Icon(allowed?Icons.chevron_right:Icons.lock_outline),onTap:allowed?open:null);
  Future<void> _edit(CoachClientRelationship relationship)async{
    final selected=relationship.permissions.toSet();
    final result=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,update)=>AlertDialog(
      title:const Text('Qué puede ver mi entrenador'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        for(final p in CoachPermission.values)CheckboxListTile(title:Text(_permissionLabel(p)),value:selected.contains(p),
          onChanged:(value)=>update((){if(value==true){selected.add(p);}else{selected.remove(p);}})),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Guardar permisos'))])));
    if(!mounted||result!=true||ref.read(appIdentityProvider).userId!=_viewerId)return;
    await ref.read(coachClientProvider.notifier).setPermissions(relationshipId:relationship.id,permissions:selected);
  }
  Future<void> _revoke(CoachClientRelationship relationship)async{
    final result=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('Revocar acceso'),content:const Text('El entrenador perderá acceso a los datos de esta relación. Se conserva el historial personal.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Revocar'))]));
    if(!mounted||result!=true||ref.read(appIdentityProvider).userId!=_viewerId)return;
    await ref.read(coachClientProvider.notifier).revokeRelationship(relationship.id);
  }
}
String _permissionLabel(CoachPermission p)=>switch(p){
  CoachPermission.viewWorkouts=>'Ver entrenamientos',CoachPermission.viewProgress=>'Ver progreso',
  CoachPermission.viewMeasurements=>'Ver medidas',CoachPermission.assignPrograms=>'Asignar programas',
  CoachPermission.assignTasks=>'Asignar tareas',CoachPermission.viewCheckins=>'Ver check-ins',
  CoachPermission.viewNutrition=>'Ver alimentación',CoachPermission.comment=>'Comentar',
};
