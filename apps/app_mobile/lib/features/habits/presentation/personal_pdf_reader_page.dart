import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:core/features/habits/application/habit_integrity_policy.dart';
import 'package:uuid/uuid.dart';
import '../data/personal_reading_library.dart';

/// A common offline page reader. Native code renders one bounded page at a
/// time; no file leaves the device. The last visible page is checkpointed.
class PersonalPdfReaderPage extends ConsumerStatefulWidget {
  final PersonalReadingDocument document;
  final PersonalReadingLibraryRepository repository;
  const PersonalPdfReaderPage({super.key,required this.document,required this.repository});
  @override
  ConsumerState<PersonalPdfReaderPage> createState()=>_PersonalPdfReaderPageState();
}
class _PersonalPdfReaderPageState extends ConsumerState<PersonalPdfReaderPage> with WidgetsBindingObserver {
  static const _channel=MethodChannel('stk_haven/pdf_reader');
  late PersonalReadingDocument _doc;
  final _watch=Stopwatch();
  final _session=const Uuid().v4();
  final _started=DateTime.now();
  late int _first;
  Uint8List? _bytes;
  Timer? _ticker;
  bool _busy=false;
  bool _tracking=false;
  bool _linked=false;
  String? _error;
  @override
  void initState(){
    super.initState();_doc=widget.document;_first=_doc.currentPage;
    WidgetsBinding.instance.addObserver(this);
    _ticker=Timer.periodic(const Duration(seconds:15),(_){if(_tracking){unawaited(_save().then<void>((_){}));}});
    WidgetsBinding.instance.addPostFrameCallback((_){if(mounted&&!_doc.physical)unawaited(_load(_doc.currentPage));});
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state!=AppLifecycleState.resumed&&_tracking){
      if(!_doc.physical){_watch.stop();_tracking=false;}
      unawaited(_save().then<void>((_){}));
      if(mounted)setState((){});
    }
  }
  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();_watch.stop();unawaited(_save().then<void>((_){}));super.dispose();
  }
  Future<bool> _save()async{
    try{
      await widget.repository.checkpoint(_doc.id,page:_doc.currentPage,totalPages:_doc.totalPages,
        session:ReadingSession(id:_session,startedAt:_started,seconds:_watch.elapsed.inSeconds,
          pagesAdvanced:(_doc.currentPage-_first).clamp(0,1000000).toInt()));
      return true;
    }catch(_){if(mounted)setState(()=>_error='No se pudo guardar el progreso.');return false;}
  }
  Future<void> _load(int page)async{
    if(_busy)return;
    setState((){_busy=true;_error=null;});
    try{
      if(_doc.physical){
        _doc=_doc.copyWith(currentPage:page.clamp(1,_doc.totalPages).toInt());
      }else{
        final result=await _channel.invokeMapMethod<String,dynamic>('renderPage',{'path':_doc.localPath,'page':page,'highlightTerms':_doc.highlights[page]??const <String>[]});
        if(result==null||result['bytes'] is! Uint8List)throw StateError('PDF no disponible');
        if(!mounted)return;
        _bytes=result['bytes'] as Uint8List;
        _doc=_doc.copyWith(currentPage:(result['currentPage'] as num).toInt(),totalPages:(result['totalPages'] as num).toInt());
      }
      await _save();
    }catch(_){if(mounted)setState(()=>_error='No se pudo abrir esta página. Comprueba el archivo.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _linkHabit()async{
    if(_linked||_watch.elapsed.inSeconds<=0)return;
    final notifier=ref.read(habitTasksProvider.notifier);
    final now=DateTime.now();
    final state=ref.read(habitTasksProvider);
    final candidates=state.tasks.where((t)=>!t.faithSpecific&&t.source!=HabitTaskSource.coach&&t.type==HabitTaskType.readingTimer&&HabitIntegrityPolicy.pending(t,state.completions,now)).toList();
    if(candidates.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No tienes un hábito de lectura pendiente.')));return;}
    final id=await showDialog<String>(context:context,builder:(ctx)=>SimpleDialog(title:const Text('Vincular a un hábito de lectura'),children:[
      for(final task in candidates)SimpleDialogOption(onPressed:()=>Navigator.pop(ctx,task.id),child:Text(task.title)),
      SimpleDialogOption(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),
    ]));
    if(id==null||!mounted)return;
    try{
      _watch.stop();_tracking=false;if(!await _save())return;
      await notifier.completeTask(taskId:id,minutesSpent:_watch.elapsed.inMinutes,completionId:'reading:$_session');
      if(mounted)setState(()=>_linked=true);
    }catch(_){if(mounted)setState(()=>_error='No se pudo vincular el hábito.');}
  }
  Future<void> _manualReading()async{
    final controller=TextEditingController();
    final minutes=await showDialog<int>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Registrar lectura anterior'),
      content:TextField(controller:controller,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Minutos reales')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,int.tryParse(controller.text)),child:const Text('Registrar'))]));
    controller.dispose();if(minutes==null||minutes<1||minutes>1440||!mounted)return;
    await widget.repository.update(_doc.id,(d)=>d.copyWith(lastReadAt:DateTime.now(),sessions:[...d.sessions,
      ReadingSession(id:const Uuid().v4(),startedAt:DateTime.now(),seconds:minutes*60,pagesAdvanced:0)]));
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Lectura registrada.')));
  }
  Future<void> _searchText()async{
    final controller=TextEditingController();
    final query=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Buscar en PDF'),
      content:TextField(controller:controller,decoration:const InputDecoration(hintText:'Palabra o frase')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),child:const Text('Buscar'))]));
    controller.dispose();if(query==null||query.isEmpty||!mounted)return;
    setState(()=>_busy=true);
    try{
      final pages=await _channel.invokeListMethod<int>('searchText',{'path':_doc.localPath,'query':query});
      if(!mounted)return;
      setState(()=>_busy=false);
      final page=await showModalBottomSheet<int>(context:context,builder:(ctx)=>SafeArea(child:ListView(shrinkWrap:true,children:[
        const ListTile(title:Text('Resultados de búsqueda')),
        if(pages==null||pages.isEmpty)const ListTile(title:Text('Sin coincidencias en texto extraíble')),
        for(final page in pages??const <int>[])ListTile(title:Text('Página $page'),onTap:()=>Navigator.pop(ctx,page)),
      ])));
      if(page!=null&&mounted){
        await _load(page);
        if(!mounted||_error!=null)return;
        final mark=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Resaltar coincidencias'),
          content:Text('¿Resaltar "$query" en esta página?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('No')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Resaltar'))]));
        if(mark==true&&mounted){
          final next=await widget.repository.update(_doc.id,(d)=>d.copyWith(highlights:{...d.highlights,page:[...{...?d.highlights[page],query}]}));
          if(next!=null&&mounted){_doc=next;await _load(page);}
        }
      }
    }on PlatformException catch(e){if(mounted)setState(()=>_error=e.code=='pdf_search_unavailable'?'La búsqueda de texto no está disponible en esta versión de Android o en este PDF.':'No se pudo buscar en el archivo.');}
    catch(_){if(mounted)setState(()=>_error='No se pudo buscar en el archivo.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _jump()async{
    final controller=TextEditingController(text:'${_doc.currentPage}');
    final page=await showDialog<int>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Ir a página'),content:TextField(controller:controller,keyboardType:TextInputType.number),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,int.tryParse(controller.text)),child:const Text('Ir'))]));
    controller.dispose();
    if(page!=null&&mounted)await _load(page);
  }
  Future<void> _bookmark()async{
    final page=_doc.currentPage;
    final next=await widget.repository.update(_doc.id,(d){
      final marks={...d.bookmarks};
      if(!marks.add(page))marks.remove(page);
      return d.copyWith(bookmarks:marks);
    });
    if(next!=null&&mounted)setState(()=>_doc=next);
  }
  Future<void> _note()async{
    final page=_doc.currentPage;
    final controller=TextEditingController(text:_doc.pageNotes[page]??'');
    final text=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('Nota · página $page'),content:TextField(controller:controller,minLines:3,maxLines:7),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),child:const Text('Guardar'))]));
    controller.dispose();
    if(text==null||!mounted)return;
    final next=await widget.repository.update(_doc.id,(d){
      final notes={...d.pageNotes};
      if(text.isEmpty){notes.remove(page);}else{notes[page]=text;}
      return d.copyWith(pageNotes:notes);
    });
    if(next!=null&&mounted)setState(()=>_doc=next);
  }
  Future<void> _marks()async{
    final pages=_doc.bookmarks.toList()..sort();
    final page=await showModalBottomSheet<int>(context:context,builder:(ctx)=>SafeArea(child:ListView(shrinkWrap:true,children:[
      const ListTile(title:Text('Marcadores')),
      if(pages.isEmpty)const ListTile(title:Text('Todavía no hay marcadores')),
      for(final p in pages)ListTile(title:Text('Página $p'),onTap:()=>Navigator.pop(ctx,p)),
    ])));
    if(page!=null&&mounted)await _load(page);
  }
  void _toggle(){
    setState((){
      _tracking=!_tracking;
      if(_tracking){_watch.start();}else{_watch.stop();}
    });
    if(!_tracking)unawaited(_save().then<void>((_){}));
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(_doc.title,overflow:TextOverflow.ellipsis),actions:[
      if(!_doc.physical)IconButton(tooltip:'Buscar texto',onPressed:_busy?null:_searchText,icon:const Icon(Icons.search)),
      IconButton(tooltip:'Marcadores',onPressed:_busy?null:_marks,icon:const Icon(Icons.bookmarks_outlined)),
      if((_doc.highlights[_doc.currentPage]??const <String>[]).isNotEmpty)IconButton(tooltip:'Quitar resaltados de página',icon:const Icon(Icons.format_color_reset),onPressed:_busy?null:()async{
        final page=_doc.currentPage;final next=await widget.repository.update(_doc.id,(d)=>d.copyWith(highlights:{...d.highlights}..remove(page)));
        if(next!=null&&mounted){_doc=next;await _load(page);}
      }),
      IconButton(tooltip:'Marcar página',onPressed:_busy?null:_bookmark,
        icon:Icon(_doc.bookmarks.contains(_doc.currentPage)?Icons.bookmark:Icons.bookmark_border)),
    ]),
    body:Column(children:[
      if(_error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      Expanded(child:Center(child:_busy?const CircularProgressIndicator():_doc.physical?
        Column(mainAxisSize:MainAxisSize.min,children:[
          const Icon(Icons.menu_book_outlined,size:72),const SizedBox(height:16),
          Text('Libro físico',style:Theme.of(context).textTheme.titleLarge),
          Text('Página ${_doc.currentPage} de ${_doc.totalPages}'),
          TextButton(onPressed:_jump,child:const Text('Actualizar página')),
          TextButton(onPressed:_tracking?null:_manualReading,child:const Text('Registrar minutos manualmente')),
        ]):_bytes==null?TextButton(onPressed:()=>_load(_doc.currentPage),child:const Text('Reintentar')):
        InteractiveViewer(key:ValueKey(_doc.currentPage),minScale:1,maxScale:5,child:Image.memory(_bytes!,fit:BoxFit.contain)))),
      SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(12),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Row(children:[
          IconButton(tooltip:'Página anterior',onPressed:_busy||_doc.currentPage<=1?null:()=>_load(_doc.currentPage-1),icon:const Icon(Icons.chevron_left)),
          Expanded(child:TextButton(onPressed:_busy||_doc.totalPages==0?null:_jump,child:Text('${_doc.currentPage} / ${_doc.totalPages}'))),
          IconButton(tooltip:'Página siguiente',onPressed:_busy||_doc.currentPage>=_doc.totalPages?null:()=>_load(_doc.currentPage+1),icon:const Icon(Icons.chevron_right)),
          IconButton(tooltip:'Nota de página',onPressed:_note,icon:const Icon(Icons.edit_note)),
        ]),
        FilledButton.icon(onPressed:_linked||_busy||(!_doc.physical&&_bytes==null)?null:_toggle,icon:Icon(_tracking?Icons.pause:Icons.play_arrow),
          label:Text(_linked?'Sesión vinculada':_tracking?'Pausar registro de lectura':'Registrar tiempo de lectura')),
        if(!_tracking&&_watch.elapsed.inSeconds>0&&!_linked)TextButton(onPressed:_linkHabit,child:const Text('Vincular tiempo a un hábito de lectura')),
        if(_doc.totalPages>0&&_doc.currentPage==_doc.totalPages)
          TextButton(onPressed:()async{
            await _save();
            await widget.repository.update(_doc.id,(d)=>d.copyWith(finished:true));
            if(context.mounted)Navigator.pop(context);
          },child:const Text('Marcar libro terminado')),
      ]))),
    ]),
  );
}
