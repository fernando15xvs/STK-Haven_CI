import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gym_tracker/core/layout/mobile_content_frame.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import '../data/private_journal_repository.dart';

class PrivateJournalPage extends StatefulWidget{
  const PrivateJournalPage({super.key});
  @override State<PrivateJournalPage> createState()=>_PrivateJournalPageState();
}
class _PrivateJournalPageState extends State<PrivateJournalPage> with WidgetsBindingObserver {
  final _repo=PrivateJournalRepository();
  final _search=TextEditingController();
  List<PrivateJournalEntry> _rows=[];
  bool _loading=true;
  bool _locked=true;
  bool _requiresAuth=false;
  bool _authenticating=false;
  static const _lockKey='stk_private_journal_lock_v1';
  static const _authChannel=MethodChannel('stk_haven/private_journal');
  String? _error;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_initialize();}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);_search.dispose();super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.paused&&_requiresAuth&&!_authenticating&&mounted){setState((){_locked=true;_rows=[];});}
  }
  Future<void> _initialize()async{
    final prefs=await SharedPreferences.getInstance();if(!mounted)return;
    setState((){_requiresAuth=prefs.getBool(_lockKey)??false;_locked=_requiresAuth;_loading=false;});
    if(!_locked)await _reload();
  }
  Future<bool> _authenticate()async{
    if(_authenticating)return false;
    _authenticating=true;
    try{return await _authChannel.invokeMethod<bool>('authenticate')==true;}
    catch(_){return false;}finally{_authenticating=false;}
  }
  Future<void> _unlock()async{
    if(!await _authenticate()||!mounted)return;
    setState(()=>_locked=false);await _reload();
  }
  Future<void> _toggleLock()async{
    if(!await _authenticate()){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo autenticar. Comprueba el bloqueo del dispositivo.')));return;
    }
    final prefs=await SharedPreferences.getInstance();
    final next=!_requiresAuth;
    if(!await prefs.setBool(_lockKey,next)||!mounted)return;
    setState(()=>_requiresAuth=next);
  }
  Future<void> _reload()async{
    try{final rows=await _repo.load();if(mounted&&!_locked)setState((){_rows=rows;_loading=false;_error=null;});}
    catch(_){if(mounted)setState((){_loading=false;_error='No se pudo abrir el diario. Desbloquea tu dispositivo y reintenta.';});}
  }
  Future<void> _edit([PrivateJournalEntry? entry])async{
    final controller=TextEditingController(text:entry?.text??'');
    final text=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:Text(entry==null?'Nueva nota':'Editar nota'),
      content:TextField(controller:controller,autofocus:true,minLines:4,maxLines:10,decoration:const InputDecoration(hintText:'Escribe para ti')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text),child:const Text('Guardar'))]));
    controller.dispose();
    if(text==null||text.trim().isEmpty||!mounted)return;
    try{await _repo.put(text,id:entry?.id,kind:entry?.kind??'Nota',createdAt:entry?.createdAt);await _reload();}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo guardar la nota.')));}
  }
  Future<void> _delete(PrivateJournalEntry entry)async{
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Eliminar nota'),
      content:const Text('Esta acción elimina la nota del diario local.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Eliminar'))]));
    if(ok!=true)return;
    try{await _repo.delete(entry.id);await _reload();}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo eliminar.')));}
  }
  Future<void> _export()async{
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Exportar diario'),
      content:const Text('Las notas pueden contener información sensible. El destino que elijas puede guardar una copia fuera de STK Haven.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Compartir copia'))]));
    if(ok!=true||!mounted)return;
    final box=context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(text:_rows.map((e)=>'${e.createdAt.toLocal()} · ${e.kind}\n${e.text}').join('\n\n'),
      sharePositionOrigin:box==null?null:box.localToGlobal(Offset.zero)&box.size));
  }
  @override Widget build(BuildContext context){
    final query=_search.text.trim().toLowerCase();
    final filtered=_rows.where((e)=>e.text.toLowerCase().contains(query)||e.kind.toLowerCase().contains(query));
    if(_locked)return Scaffold(appBar:AppBar(title:const Text('Diario privado')),body:Center(child:_loading?const CircularProgressIndicator():
      FilledButton.icon(onPressed:_unlock,icon:const Icon(Icons.lock_open),label:const Text('Desbloquear diario'))));
    return Scaffold(appBar:AppBar(title:const Text('Diario privado'),actions:[IconButton(tooltip:_requiresAuth?'Desactivar bloqueo':'Activar bloqueo',onPressed:_toggleLock,icon:Icon(_requiresAuth?Icons.lock:Icons.lock_open)),IconButton(tooltip:'Exportar copia',onPressed:_rows.isEmpty?null:_export,icon:const Icon(Icons.ios_share))]),
      body:ListView(padding:SecondaryScreenInsets.scrollPadding(context,const EdgeInsets.all(16)),children:[
        const Text('Notas solo en este dispositivo. No forman parte de las copias generales de STK Haven.'),
        const SizedBox(height:16),FilledButton.icon(onPressed:_loading||_error!=null?null:()=>_edit(),icon:const Icon(Icons.add),label:const Text('Nueva nota')),
        const SizedBox(height:12),TextField(controller:_search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Buscar notas')),
        if(_loading)const Center(child:CircularProgressIndicator()),
        if(_error!=null)ListTile(title:Text(_error!),trailing:IconButton(onPressed:_reload,icon:const Icon(Icons.refresh))),
        if(!_loading&&_error==null&&_rows.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('Todavía no hay notas.')),
        for(final entry in filtered)Padding(padding:const EdgeInsets.only(top:12),child:PremiumCard(child:ListTile(contentPadding:EdgeInsets.zero,
          title:Text(entry.kind),subtitle:Text(entry.text,maxLines:4,overflow:TextOverflow.ellipsis),onTap:()=>_edit(entry),
          trailing:IconButton(tooltip:'Eliminar nota',onPressed:()=>_delete(entry),icon:const Icon(Icons.delete_outline))))),
      ]));
  }
}
