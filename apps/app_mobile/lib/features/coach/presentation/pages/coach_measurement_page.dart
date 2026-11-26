import 'package:core/features/coach/application/coach_measurement_provider.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachMeasurementPage extends ConsumerStatefulWidget {
  final String relationshipId, clientUserId, viewerUserId;
  const CoachMeasurementPage({super.key, required this.relationshipId,
    required this.clientUserId, required this.viewerUserId});
  @override ConsumerState<CoachMeasurementPage> createState()=>_CoachMeasurementPageState();
}
class _CoachMeasurementPageState extends ConsumerState<CoachMeasurementPage> with WidgetsBindingObserver {
  bool _busy=false;
  CoachMeasurementQuery get _query=>(relationshipId:widget.relationshipId,userId:widget.viewerUserId);
  bool get _isClient=>widget.viewerUserId==widget.clientUserId;
  bool get _sameSession {
    final identity=ref.read(appIdentityProvider);
    return identity.signedIn && identity.userId==widget.viewerUserId;
  }
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed && mounted) ref.invalidate(coachMeasurementProvider(_query));
  }
  @override Widget build(BuildContext context){
    final identity=ref.watch(appIdentityProvider);
    if(!identity.signedIn||identity.userId!=widget.viewerUserId){
      return Scaffold(appBar:AppBar(title:const Text('Medidas compartidas')),
        body:const Center(child:Text('La sesión cambió. Vuelve a Mi Coach.')));
    }
    final result=ref.watch(coachMeasurementProvider(_query));
    return Scaffold(
      appBar:AppBar(title:const Text('Medidas compartidas'),actions:[
        IconButton(tooltip:'Actualizar',onPressed:_busy?null:()=>ref.invalidate(coachMeasurementProvider(_query)),icon:const Icon(Icons.refresh)),
      ]),
      body:SafeArea(
        child:Center(
          child:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:680),
            child:ListView(padding:const EdgeInsets.all(20),children:[
              Text(_isClient?'Tú eliges qué compartir':'Resumen autorizado por el cliente',
                style:Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height:8),
              Text(_isClient?'Solo se envían los campos que selecciones de un registro. No se comparte tu historial completo. Puedes retirar la copia sin borrar tus medidas personales.':
                'La información corresponde al último registro que el cliente decidió compartir contigo. No es un objetivo ni un diagnóstico.'),
              const SizedBox(height:20),
              result.when(skipLoadingOnRefresh:false,skipLoadingOnReload:false,
                loading:()=>const Center(child:CircularProgressIndicator()),
                error:(_,_)=>const Text('No se pudieron consultar las medidas. Comprueba la conexión y los permisos vigentes.'),
                data:(snapshot)=>snapshot==null?const Text('Todavía no hay medidas compartidas.'):
                  Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text('Registro: ${MaterialLocalizations.of(context).formatMediumDate(snapshot.measuredAt.toLocal())}'),
                    Text('Compartido: ${MaterialLocalizations.of(context).formatMediumDate(snapshot.sharedAt.toLocal())}'),
                    const Divider(),
                    for(final entry in snapshot.values.entries) ListTile(contentPadding:EdgeInsets.zero,
                      title:Text(coachMeasurementLabels[entry.key]!),trailing:Text(entry.value.toStringAsFixed(1))),
                  ])))),
              if(_isClient)...[
                const SizedBox(height:16),
                FilledButton.icon(onPressed:_busy||result.isLoading||result.hasError?null:_choose,
                  icon:const Icon(Icons.share_outlined),label:const Text('Elegir medidas para compartir')),
                OutlinedButton.icon(onPressed:_busy||result.isLoading?null:_clear,
                  icon:const Icon(Icons.lock_outline),label:const Text('Retirar copia compartida')),
              ],
            ]),
          ),
        ),
      ),
    );
  }
  Future<void> _choose() async {
    if(!_sameSession||_busy)return;
    final records=ref.read(bodyMeasurementProvider).where((item)=>coachMeasurementValues(item).isNotEmpty).toList()
      ..sort((a,b)=>b.date.compareTo(a.date));
    if(records.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Primero registra una medida en Progreso.')));return;}
    final selectedRecord=await showModalBottomSheet<BodyMeasurement>(context:context,
      showDragHandle:true,isScrollControlled:true,builder:(context)=>SafeArea(child:SizedBox(
        height:MediaQuery.sizeOf(context).height*.60,child:ListView(padding:const EdgeInsets.all(16),children:[
          Text('Elegir registro',style:Theme.of(context).textTheme.titleLarge),
          for(final item in records) ListTile(
            title:Text(MaterialLocalizations.of(context).formatMediumDate(item.date.toLocal())),
            subtitle:Text('${coachMeasurementValues(item).length} campos registrados'),
            onTap:()=>Navigator.pop(context,item)),
        ]))));
    if(!mounted||!_sameSession||selectedRecord==null)return;
    final candidates=coachMeasurementValues(selectedRecord);
    final selected=<String>{};
    final confirmed=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setDialogState)=>AlertDialog(
      title:const Text('Confirmar datos compartidos'),
      content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('Selecciona los campos. Ninguno viene marcado por defecto. Esto reemplaza tu copia anterior.'),
        for(final entry in candidates.entries) CheckboxListTile(contentPadding:EdgeInsets.zero,
          title:Text(coachMeasurementLabels[entry.key]!),subtitle:Text(entry.value.toStringAsFixed(1)),
          value:selected.contains(entry.key),onChanged:(value)=>setDialogState((){if(value==true){selected.add(entry.key);}else{selected.remove(entry.key);}})),
      ]))),actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),
        FilledButton(onPressed:selected.isEmpty?null:()=>Navigator.pop(context,true),child:const Text('Compartir')),
      ])));
    if(!mounted||!_sameSession||confirmed!=true)return;
    await _mutate(()=>ref.read(coachMeasurementServiceProvider).share(widget.relationshipId,selectedRecord.date,
      {for(final key in selected) key:candidates[key]!}), 'Medidas compartidas.');
  }
  Future<void> _clear() async {
    final confirmed=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('Retirar medidas'),content:const Text('Se elimina la copia compartida, no tus medidas personales.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),
      FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Retirar'))]));
    if(!mounted||!_sameSession||confirmed!=true)return;
    await _mutate(()=>ref.read(coachMeasurementServiceProvider).clear(widget.relationshipId),'Copia compartida retirada.');
  }
  Future<void> _mutate(Future<void> Function() action,String message) async{
    if(!_sameSession||_busy)return;
    setState(()=>_busy=true);
    try{
      await action();
      if(mounted&&_sameSession)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
    }catch(_){
      if(mounted&&_sameSession)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo completar. Comprueba tus permisos y conexión.')));
    }finally{
      if(mounted){setState(()=>_busy=false);ref.invalidate(coachMeasurementProvider(_query));}
    }
  }
}
