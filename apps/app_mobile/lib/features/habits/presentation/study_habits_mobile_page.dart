import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/habit_integrity_policy.dart';
import 'package:core/features/habits/application/habit_schedule_service.dart';
import 'package:core/features/habits/application/habit_study_timer_provider.dart';
import 'package:core/features/habits/application/focus_timer_notification_service.dart';
import 'package:core/features/habits/application/habit_task_templates.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:core/features/coach/application/coach_task_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/layout/mobile_content_frame.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/features/faith/presentation/pages/bible_reader_page.dart';
import 'package:gym_tracker/features/coach/presentation/pages/coach_hub_page.dart';
import '../data/personal_reading_library.dart';
import '../data/private_journal_repository.dart';
import 'pages/habit_study_timer_page.dart';
import 'personal_pdf_reader_page.dart';
import 'recovery_pause_page.dart';
import 'wind_down_page.dart';
import 'private_journal_page.dart';

class StudyHabitsMobilePage extends ConsumerStatefulWidget {
  const StudyHabitsMobilePage({super.key});
  @override
  ConsumerState<StudyHabitsMobilePage> createState()=>_StudyHabitsMobilePageState();
}
class _StudyHabitsMobilePageState extends ConsumerState<StudyHabitsMobilePage> with WidgetsBindingObserver {
  final _library=PersonalReadingLibraryRepository();
  List<PersonalReadingDocument> _documents=[];
  final _search=TextEditingController();
  final _covers=<String,Future<Uint8List?>>{};
  Timer? _clock;
  int _tab=0;
  int _filter=0;
  int _focus=25;
  bool _notifyFocus=false;
  bool _loading=true;
  bool _importing=false;
  String? _libraryError;
  final _busy=<String>{};

  @override
  void initState(){
    super.initState();WidgetsBinding.instance.addObserver(this);
    _clock=Timer.periodic(const Duration(seconds:30),(_){if(mounted)setState((){});});
    unawaited(_reload());
    WidgetsBinding.instance.addPostFrameCallback((_)async{
      if(!mounted)return;
      try{await PrivateJournalRepository().migrateLegacy(ref.read(habitTaskRepositoryProvider));if(mounted)ref.read(habitTasksProvider.notifier).refresh();}
      catch(_){_message('No se pudieron mover las notas anteriores al diario privado. Siguen en tu dispositivo.');}
    });
  }
  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);_clock?.cancel();_search.dispose();super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed&&mounted){setState((){});unawaited(_reload());}
  }
  void _message(String message){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));}
  Future<void> _reload()async{
    try{
      final docs=await _library.load();
      if(mounted)setState((){_documents=docs;_loading=false;_libraryError=null;});
    }catch(_){if(mounted)setState((){_loading=false;_libraryError='No se pudo cargar la biblioteca. Tus archivos no se han eliminado.';});}
  }
  Future<void> _route(Widget page)async{
    await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>page));
    if(mounted){await _reload();if(mounted)setState((){});}
  }
  Future<void> _import()async{
    if(_importing)return;
    setState(()=>_importing=true);
    try{final doc=await _library.importPdf();if(doc!=null&&mounted)await _openBook(doc);}
    catch(_){_message('No se pudo importar este PDF. Comprueba el archivo y el espacio disponible.');}
    finally{if(mounted){setState(()=>_importing=false);await _reload();}}
  }
  Future<void> _openBook(PersonalReadingDocument doc)=>_route(PersonalPdfReaderPage(document:doc,repository:_library));
  Future<void> _editBook([PersonalReadingDocument? doc])async{
    final title=TextEditingController(text:doc?.title??'');
    final author=TextEditingController(text:doc?.author??'');
    final pages=TextEditingController(text:doc==null?'':'${doc.totalPages}');
    final goal=TextEditingController(text:'${doc?.goalDays??30}');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(doc==null?'Añadir libro físico':'Editar libro'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Título')),
        TextField(controller:author,decoration:const InputDecoration(labelText:'Autor (opcional)')),
        if(doc==null)TextField(controller:pages,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Páginas totales')),
        TextField(controller:goal,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Días para terminar')),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Guardar'))]));
    final name=title.text.trim(),writer=author.text.trim(),count=int.tryParse(pages.text)??0,days=int.tryParse(goal.text)??0;
    title.dispose();author.dispose();pages.dispose();goal.dispose();
    if(ok!=true||!mounted)return;
    if(name.isEmpty||days<1||days>365||(doc==null&&count<1)){_message('Revisa el título, las páginas y el plazo (1–365 días).');return;}
    try{
      final book=doc??await _library.addPhysical(name,count,author:writer);
      await _library.update(book.id,(d)=>d.copyWith(title:name,author:writer,goalDays:days,goalStartedAt:DateTime.now()));
      await _reload();
    }catch(_){_message('No se pudo guardar el libro.');}
  }
  Future<void> _bookMenu(PersonalReadingDocument doc,String action)async{
    try{
      if(action=='edit'){await _editBook(doc);return;}
      if(action=='favorite')await _library.update(doc.id,(d)=>d.copyWith(favorite:!d.favorite));
      if(action=='finish')await _library.update(doc.id,(d)=>d.copyWith(finished:!d.finished));
      if(action=='delete'){
        final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
          title:const Text('Eliminar libro'),content:Text('Se quitará "${doc.title}" y sus notas y progreso locales. El archivo original importado no cambia.'),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Eliminar'))]));
        if(ok==true)await _library.remove(doc);
      }
      await _reload();
    }catch(_){_message('No se pudo actualizar el libro.');}
  }
  Future<void> _editHabit([HabitTask? task])async{
    final name=TextEditingController(text:task?.title??'');
    final category=TextEditingController(text:task?.category??'General');
    final minutes=TextEditingController(text:'${task?.targetMinutes??20}');
    var kind=task?.targetQuantity!=null?'quantity':task?.type==HabitTaskType.readingTimer||task?.type==HabitTaskType.studySession||((task?.targetMinutes??0)>0&&task?.type!=HabitTaskType.reflection)?'time':'check';
    final amount=TextEditingController(text:'${task?.targetQuantity??1}');
    final unit=TextEditingController(text:task?.quantityUnit??'');
    var onceDate=task?.scheduledAt?.toLocal()??DateTime.now();
    var mode=task?.weeklyGoal!=null?'flex':task?.recurrence==HabitRecurrenceType.weekly?'weekly':
      task?.recurrence==HabitRecurrenceType.once?'once':'daily';
    var target=task?.weeklyGoal??3;
    final weekdays=<int>{...?task?.weekdays};
    if(weekdays.isEmpty)weekdays.add(DateTime.now().weekday);
    final result=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,change)=>AlertDialog(
      title:Text(task==null?'Nuevo hábito':'Editar hábito'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          TextField(controller:name,decoration:const InputDecoration(labelText:'Nombre')),
          TextField(controller:category,decoration:const InputDecoration(labelText:'Categoría')),
          DropdownButton<String>(isExpanded:true,value:kind,items:const [DropdownMenuItem(value:'check',child:Text('Marcar como realizado')),
            DropdownMenuItem(value:'time',child:Text('Medir tiempo')),DropdownMenuItem(value:'quantity',child:Text('Registrar cantidad'))],onChanged:(v)=>change(()=>kind=v??kind)),
          if(kind=='time')TextField(controller:minutes,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Minutos objetivo')),
          if(kind=='quantity')...[
            TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Cantidad objetivo')),
            TextField(controller:unit,decoration:const InputDecoration(labelText:'Unidad (p. ej. páginas, palabras)')),
          ],
          const SizedBox(height:12),const Text('Frecuencia'),
          DropdownButton<String>(isExpanded:true,value:mode,items:const [
            DropdownMenuItem(value:'daily',child:Text('Todos los días')),DropdownMenuItem(value:'weekly',child:Text('Días específicos')),
            DropdownMenuItem(value:'flex',child:Text('Objetivo semanal flexible')),DropdownMenuItem(value:'once',child:Text('Una sola vez')),
          ],onChanged:(v)=>change(()=>mode=v??mode)),
          if(mode=='once')TextButton.icon(icon:const Icon(Icons.calendar_today),label:Text('${onceDate.day}/${onceDate.month}/${onceDate.year}'),onPressed:()async{
            final now=DateTime.now();final selected=await showDatePicker(context:ctx,initialDate:onceDate.isBefore(now)?now:onceDate,firstDate:DateTime(now.year,now.month,now.day),lastDate:DateTime(now.year+2));
            if(selected!=null)change(()=>onceDate=selected);
          }),
          if(mode=='weekly')Wrap(spacing:6,children:[for(final (i,label) in ['L','M','X','J','V','S','D'].indexed)
            FilterChip(label:Text(label),selected:weekdays.contains(i+1),onSelected:(v)=>change((){if(v){weekdays.add(i+1);}else{weekdays.remove(i+1);}}))]),
          if(mode=='flex')...[
            Text('$target días por semana'),Slider(value:target.toDouble(),min:1,max:7,divisions:6,onChanged:(v)=>change(()=>target=v.round())),
          ],
        ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Guardar'))])));
    final title=name.text.trim(),cat=category.text.trim(),mins=int.tryParse(minutes.text)??0;
    final quantity=double.tryParse(amount.text.replaceAll(',','.')),quantityUnit=unit.text.trim();
    name.dispose();category.dispose();minutes.dispose();amount.dispose();unit.dispose();
    final timed=kind=='time';
    final type=timed?HabitTaskType.studySession:kind=='quantity'?HabitTaskType.custom:HabitTaskType.checklist;
    if(result!=true||!mounted)return;
    if(title.isEmpty||(timed&&(mins<1||mins>1440))||(kind=='quantity'&&(quantity==null||!quantity.isFinite||quantity<=0||quantityUnit.isEmpty))||(mode=='weekly'&&weekdays.isEmpty)){_message('Revisa los datos del hábito.');return;}
    final recurrence=mode=='daily'?HabitRecurrenceType.daily:mode=='once'?HabitRecurrenceType.once:HabitRecurrenceType.weekly;
    final notifier=ref.read(habitTasksProvider.notifier);
    try{
      if(task==null){
        await notifier.createTask(title:title,category:cat,type:type,targetQuantity:kind=='quantity'?quantity:null,quantityUnit:quantityUnit,
          targetMinutes:timed?mins:0,recurrence:recurrence,scheduledAt:mode=='once'?onceDate:null,weekdays:mode=='weekly'?weekdays:{},weeklyGoal:mode=='flex'?target:null);
      }else{
        await notifier.updateTask(task.copyWith(title:title,category:cat.isEmpty?'General':cat,
          type:task.sourceReference.startsWith('template:')?task.type:type,
          targetQuantity:kind=='quantity'?quantity:null,clearTargetQuantity:kind!='quantity',quantityUnit:quantityUnit,
          targetMinutes:timed?mins:0,recurrence:recurrence,scheduledAt:mode=='once'?onceDate:null,weekdays:mode=='weekly'?weekdays:{},weeklyGoal:mode=='flex'?target:null,clearWeeklyGoal:mode!='flex'));
      }
    }catch(_){_message('No se pudo guardar el hábito.');}
  }
  Future<void> _reminder(HabitTask task)async{
    final notifier=ref.read(habitTasksProvider.notifier);
    if(task.reminderEnabled){
      final mode=await showDialog<String>(context:context,builder:(ctx)=>SimpleDialog(title:const Text('Recordatorio'),children:[
        SimpleDialogOption(onPressed:()=>Navigator.pop(ctx,'edit'),child:const Text('Cambiar hora')),
        SimpleDialogOption(onPressed:()=>Navigator.pop(ctx,'off'),child:const Text('Desactivar')),
      ]));
      if(mode==null||!mounted)return;
      if(mode=='off'){await notifier.setReminder(taskId:task.id,enabled:false);return;}
    }
    final time=await showTimePicker(context:context,initialTime:task.scheduledAt==null?const TimeOfDay(hour:20,minute:30):TimeOfDay.fromDateTime(task.scheduledAt!.toLocal()));
    if(time==null||!mounted)return;
    final now=DateTime.now();
    final start=task.scheduledAt?.toLocal()??now;
    final ok=await notifier.setReminder(taskId:task.id,enabled:true,scheduledAt:DateTime(start.year,start.month,start.day,time.hour,time.minute));
    _message(ok?'Recordatorio guardado.':'No se pudo activar. Revisa los permisos y la fecha.');
  }
  Future<void> _taskMenu(HabitTask task,String action)async{
    final notifier=ref.read(habitTasksProvider.notifier);
    try{
      if(action=='edit'){await _editHabit(task);}
      if(action=='reminder'){await _reminder(task);}
      if(action=='skip'){await notifier.completeTask(taskId:task.id,status:HabitTaskCompletionStatus.skipped);}
      if(action=='resume'){await notifier.updateTask(HabitIntegrityPolicy.resume(task,DateTime.now()));}
      if(action=='pause'){
        final now=DateTime.now();
        final until=await showDatePicker(context:context,initialDate:DateTime(now.year,now.month,now.day+1),
          firstDate:DateTime(now.year,now.month,now.day+1),lastDate:DateTime(now.year+1,now.month,now.day),
          helpText:'Fecha para reanudar');
        if(until!=null&&mounted)await notifier.updateTask(HabitIntegrityPolicy.pause(task,now,until));
      }
      if(action=='archive'){
        final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Archivar hábito'),
          content:const Text('Se conserva el historial y se desactivan los recordatorios.'),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Archivar'))]));
        if(ok==true)await notifier.archiveTask(task.id);
      }
    }catch(_){_message('No se pudo actualizar el hábito.');}
  }
  Future<void> _run(HabitTask task)async{
    if(!_busy.add(task.id))return;
    try{
      if(task.source==HabitTaskSource.coach){await _route(const CoachHubPage());return;}
      if(task.faithSpecific){
        await _route(const BibleReaderPage());
        if(!mounted)return;
        final done=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('¿Completaste este hábito?'),
          content:const Text('Se registrará sin inventar minutos de lectura.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Todavía no')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Registrar'))]));
        if(done==true&&mounted)await ref.read(habitTasksProvider.notifier).completeTask(taskId:task.id);
        return;
      }
      if(task.sourceReference=='template:wind_down'||task.title==HabitTaskTemplates.windDown10Minutes.title){await _route(const WindDownPage());return;}
      if(task.sourceReference=='template:personal_pause'||task.title==HabitTaskTemplates.recoveryPause.title){await _route(const RecoveryPausePage());return;}
      if(task.targetQuantity!=null){
        final controller=TextEditingController();
        final value=await showDialog<double>(context:context,builder:(ctx)=>AlertDialog(title:Text('Registrar ${task.quantityUnit}'),
          content:TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Cantidad realizada')),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,double.tryParse(controller.text.replaceAll(',','.'))),child:const Text('Registrar'))]));
        controller.dispose();if(value!=null&&value.isFinite&&value>0&&mounted)await ref.read(habitTasksProvider.notifier).completeTask(taskId:task.id,quantity:value);
        return;
      }
      if(task.type==HabitTaskType.readingTimer||task.type==HabitTaskType.studySession||task.targetMinutes>0){
        await _route(HabitStudyTimerPage(task:task));return;
      }
      await ref.read(habitTasksProvider.notifier).completeTask(taskId:task.id);
    }catch(_){_message('No se pudo registrar el hábito.');}
    finally{_busy.remove(task.id);}
  }
  Future<void> _history(List<HabitTask> tasks,List<HabitTaskCompletion> rows)async{
    final byId={for(final t in tasks)t.id:t};
    await showModalBottomSheet<void>(context:context,useSafeArea:true,isScrollControlled:true,builder:(ctx)=>
      SizedBox(height:MediaQuery.sizeOf(ctx).height*.8,child:ListView(padding:const EdgeInsets.all(20),children:[
        Text('Historial de hábitos',style:Theme.of(ctx).textTheme.titleLarge),
        if(rows.isEmpty)const ListTile(title:Text('Todavía no hay registros')),
        for(final row in rows.where((r)=>byId.containsKey(r.taskId)))ListTile(
          title:Text(byId[row.taskId]!.title),
          subtitle:Text('${row.completedAt.toLocal().day}/${row.completedAt.toLocal().month}/${row.completedAt.toLocal().year} · ${row.status==HabitTaskCompletionStatus.skipped?'Omitido':'Completado'}${row.minutesSpent>0?' · ${row.minutesSpent} min':''}'),
          trailing:byId[row.taskId]!.source==HabitTaskSource.coach?null:IconButton(tooltip:'Deshacer registro',icon:const Icon(Icons.undo),onPressed:()async{
            await ref.read(habitTasksProvider.notifier).undoCompletion(row.id);
            if(ctx.mounted)Navigator.pop(ctx);
          }),
        ),
      ])));
  }
  Widget _heading(String title,{Widget? action})=>Row(children:[
    Expanded(child:Text(title,style:Theme.of(context).textTheme.titleLarge)),if(action!=null)action,
  ]);
  Widget _gap()=>const SizedBox(height:16);
  Widget _habitRow(HabitTask task,List<HabitTaskCompletion> rows,DateTime now){
    final done=HabitScheduleService.isCompletedOn(task,rows,now);
    final resolved=HabitScheduleService.isResolvedOn(task,rows,now);
    final paused=task.pausedUntil!=null&&HabitIntegrityPolicy.day(now).isBefore(HabitIntegrityPolicy.day(task.pausedUntil!));
    final pending=HabitIntegrityPolicy.pending(task,rows,now);
    final goal=task.weeklyGoal;
    final subtitle=<String>[
      if(paused)'En pausa' else if(done)'Completado hoy' else if(resolved)'Omitido' else if(pending)'Pendiente' else 'No previsto hoy',
      if(goal!=null)'${HabitIntegrityPolicy.completedDays(task,rows,now)}/$goal días esta semana',
      if(task.targetMinutes>0)'${task.targetMinutes} min',
      if(task.targetQuantity!=null)'${HabitScheduleService.quantityOn(task,rows,now).toStringAsFixed(1)}/${task.targetQuantity} ${task.quantityUnit}',
      if(task.source==HabitTaskSource.coach)'Coach',
    ].join(' · ');
    return ListTile(contentPadding:EdgeInsets.zero,
      leading:Icon(done?Icons.check_circle_outline:resolved?Icons.remove_circle_outline:task.targetMinutes>0?Icons.play_circle_outline:Icons.circle_outlined,
        color:done?Theme.of(context).colorScheme.primary:null),
      title:Text(task.title),subtitle:Text(subtitle),
      onTap:pending?()=>_run(task):null,
      trailing:task.source==HabitTaskSource.coach?IconButton(tooltip:'Abrir Coach',icon:const Icon(Icons.chevron_right),onPressed:()=>_route(const CoachHubPage())):
        PopupMenuButton<String>(onSelected:(v)=>_taskMenu(task,v),itemBuilder:(_)=>[
          const PopupMenuItem(value:'edit',child:Text('Editar')),
          const PopupMenuItem(value:'reminder',child:Text('Recordatorio')),
          if(pending)const PopupMenuItem(value:'skip',child:Text('Omitir hoy')),
          PopupMenuItem(value:paused?'resume':'pause',child:Text(paused?'Reanudar':'Pausar hasta…')),
          const PopupMenuItem(value:'archive',child:Text('Archivar')),
        ]),
    );
  }
  List<Widget> _habits(List<HabitTask> tasks,List<HabitTaskCompletion> rows,DateTime now){
    final pending=tasks.where((t)=>HabitIntegrityPolicy.pending(t,rows,now)).toList();
    final done=HabitIntegrityPolicy.completedToday(tasks.where((t)=>HabitScheduleService.isDueOn(t,now)),rows,now);
    final total=tasks.where((t)=>HabitScheduleService.isDueOn(t,now)&&
      (HabitIntegrityPolicy.pending(t,rows,now)||HabitScheduleService.isResolvedOn(t,rows,now))).length;
    final active=ref.watch(habitStudyTimerProvider);
    final activeTask=ref.watch(habitTasksProvider).tasks.where((t)=>t.id==active?.taskId).firstOrNull;
    final week=HabitIntegrityPolicy.week(now);
    return [
      _heading('Mi día',action:TextButton.icon(onPressed:()=>_editHabit(),icon:const Icon(Icons.add),label:const Text('Nuevo'))),
      PremiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('$done/$total',style:Theme.of(context).textTheme.headlineMedium),
        Text('$done completados · ${pending.length} pendientes'),
        const SizedBox(height:10),LinearProgressIndicator(value:total==0?0:(done/total).clamp(0.0,1.0).toDouble()),
      ])),_gap(),
      if(activeTask!=null)...[PremiumCard(child:ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.timer_outlined),
        title:Text('Sesión activa · ${activeTask.title}'),trailing:const Icon(Icons.chevron_right),onTap:()=>_resumeTask(activeTask))),_gap()],
      _heading('Mis hábitos'),
      PremiumCard(child:Column(children:[
        if(tasks.isEmpty)const ListTile(title:Text('Crea tu primer hábito'),subtitle:Text('Organiza las actividades que quieras mantener.')),
        for(final (i,task) in [...pending,...tasks.where((t)=>!pending.contains(t))].indexed)...[
          if(i>0)const Divider(height:1),
          _habitRow(task,rows,now),
        ],
      ])),_gap(),
      _heading('Constancia semanal'),
      PremiumCard(child:Row(children:[for(var i=0;i<7;i++)Expanded(child:Builder(builder:(ctx){
        final d=DateTime(week.year,week.month,week.day+i,23,59,59);
        final count=HabitIntegrityPolicy.completedToday(tasks,rows,d);
        return Column(children:[Text(['L','M','X','J','V','S','D'][i]),const SizedBox(height:6),
          CircleAvatar(radius:15,backgroundColor:count>0?Theme.of(ctx).colorScheme.primaryContainer:Theme.of(ctx).colorScheme.surfaceContainerHighest,
            child:Text('$count',style:Theme.of(ctx).textTheme.labelSmall))]);
      }))])),_gap(),
      TextButton.icon(onPressed:()=>_history(ref.read(habitTaskRepositoryProvider).getTasks(includeArchived:true).where((t)=>HabitIntegrityPolicy.isPersonalDashboardTask(t)&&(!t.faithSpecific||tasks.any((x)=>x.faithSpecific))).toList(),rows),icon:const Icon(Icons.history),label:const Text('Historial de hábitos')),
    ];
  }
  Future<Uint8List?> _cover(PersonalReadingDocument doc)=>_covers.putIfAbsent(doc.id,()async{
    if(doc.physical)return null;
    try{
      final value=await const MethodChannel('stk_haven/pdf_reader').invokeMapMethod<String,dynamic>('renderPage',{'path':doc.localPath,'page':1,'thumbnail':true});
      return value?['bytes'] as Uint8List?;
    }catch(_){return null;}
  });
  Future<void> _exportLibrary()async{
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Exportar biblioteca'),
      content:const Text('Se compartirán los PDF disponibles, el progreso y las notas de página. El destino elegido puede conservar una copia.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Compartir'))]));
    if(ok!=true||!mounted)return;
    try{
      final dir=await Directory.systemTemp.createTemp('stk_reading_export_');
      final manifest=File('${dir.path}/biblioteca.json');
      await manifest.writeAsString(jsonEncode(_documents.map((d)=>d.toJson()..remove('localPath')).toList()));
      final files=<XFile>[XFile(manifest.path)];
      for(final d in _documents){if(!d.physical&&await File(d.localPath).exists())files.add(XFile(d.localPath,name:d.originalFileName));}
      if(!mounted)return;
      final box=context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(files:files,sharePositionOrigin:box==null?null:box.localToGlobal(Offset.zero)&box.size));
      await dir.delete(recursive:true);
    }catch(_){_message('No se pudo exportar la biblioteca.');}
  }
  Widget _book(PersonalReadingDocument doc)=>PremiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    ListTile(contentPadding:EdgeInsets.zero,leading:SizedBox(width:48,height:64,child:FutureBuilder<Uint8List?>(future:_cover(doc),builder:(ctx,snapshot)=>snapshot.data==null?
      Icon(doc.physical?Icons.menu_book_outlined:Icons.picture_as_pdf_outlined,size:32,color:Theme.of(ctx).colorScheme.primary):Image.memory(snapshot.data!,fit:BoxFit.contain))),
      title:Text(doc.title),subtitle:Text([if(doc.author.isNotEmpty)doc.author,doc.finished?'Terminado':doc.totalPages==0?'Sin abrir':'Página ${doc.currentPage} de ${doc.totalPages}'].join(' · ')),
      onTap:()=>_openBook(doc),trailing:PopupMenuButton<String>(onSelected:(v)=>_bookMenu(doc,v),itemBuilder:(_)=>[
        const PopupMenuItem(value:'edit',child:Text('Editar y objetivo')),
        PopupMenuItem(value:'favorite',child:Text(doc.favorite?'Quitar favorito':'Añadir a favoritos')),
        PopupMenuItem(value:'finish',child:Text(doc.finished?'Volver a lectura':'Marcar terminado')),
        const PopupMenuItem(value:'delete',child:Text('Eliminar')),
      ])),
    if(doc.totalPages>0)LinearProgressIndicator(value:doc.progress),
    if(!doc.finished&&doc.suggestedPagesPerDay>0)Padding(padding:const EdgeInsets.only(top:8),child:Text('${doc.suggestedPagesPerDay} páginas/día · objetivo de ${doc.goalDays} días',style:Theme.of(context).textTheme.bodySmall)),
  ]));
  List<Widget> _reading(DateTime now){
    final recent=_documents.where((d)=>!d.finished&&d.lastReadAt!=null).firstOrNull;
    final query=_search.text.toLowerCase().trim();
    final filtered=_documents.where((d)=>(query.isEmpty||'${d.title} ${d.author}'.toLowerCase().contains(query))&&
      (_filter==0||_filter==1&&!d.finished&&d.lastReadAt!=null||_filter==2&&d.lastReadAt==null&&!d.finished||_filter==3&&d.finished||_filter==4&&d.favorite)).toList();
    final habits=ref.watch(habitTasksProvider);
    final seconds=ReadingStatistics.secondsLastSevenDays(_documents,now,tasks:habits.tasks,completions:habits.completions);
    return [
      if(recent!=null)...[_heading('Continuar leyendo'),_book(recent),_gap()],
      PremiumCard(child:Row(children:[
        Expanded(child:Column(children:[Text('${seconds~/60} min',style:Theme.of(context).textTheme.titleLarge),const Text('Lectura · 7 días')])),
        Expanded(child:Column(children:[Text('${_documents.where((d)=>d.finished).length}',style:Theme.of(context).textTheme.titleLarge),const Text('Terminados')])),
      ])),_gap(),
      _heading('Mi biblioteca',action:PopupMenuButton<String>(tooltip:'Añadir libro',icon:const Icon(Icons.add_circle_outline),
        onSelected:(v){if(v=='pdf'){unawaited(_import());}else{unawaited(_editBook());}},
        itemBuilder:(_)=>const [PopupMenuItem(value:'pdf',child:Text('Importar PDF')),PopupMenuItem(value:'physical',child:Text('Libro físico'))])),
      TextField(controller:_search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Buscar título o autor')),
      const SizedBox(height:8),
      Wrap(spacing:6,children:[for(final (i,label) in ['Todos','Leyendo','Por leer','Terminados','Favoritos'].indexed)
        ChoiceChip(label:Text(label),selected:_filter==i,onSelected:(_)=>setState(()=>_filter=i))]),_gap(),
      if(_loading||_importing)const Center(child:CircularProgressIndicator()),
      if(_libraryError!=null)PremiumCard(child:ListTile(title:Text(_libraryError!),trailing:IconButton(tooltip:'Reintentar',icon:const Icon(Icons.refresh),onPressed:_reload))),
      if(!_loading&&_libraryError==null&&filtered.isEmpty)const PremiumCard(child:ListTile(leading:Icon(Icons.library_books_outlined),title:Text('No hay libros en esta vista'),subtitle:Text('Importa un PDF o añade un libro físico.'))),
      for(final doc in filtered.where((d)=>d.id!=recent?.id||_filter!=0||query.isNotEmpty))...[_book(doc),const SizedBox(height:10)],
      if(_documents.isNotEmpty)TextButton.icon(onPressed:_exportLibrary,icon:const Icon(Icons.ios_share),label:const Text('Exportar biblioteca y notas')),
      OutlinedButton.icon(onPressed:()async{
        final task=await ref.read(habitTasksProvider.notifier).ensureTemplate(HabitTaskTemplates.personalReading20Minutes);
        if(mounted)await _reminder(task);
      },icon:const Icon(Icons.notifications_none),label:const Text('Recordatorio de lectura')),
    ];
  }
  Future<void> _resumeTask(HabitTask task) async {
    if(task.sourceReference=='template:breathing'){await _route(const WindDownPage(breathingOnly:true));return;}
    if(task.sourceReference=='template:wind_down'||task.title==HabitTaskTemplates.windDown10Minutes.title){await _route(const WindDownPage());return;}
    if(task.sourceReference=='template:personal_pause'||task.title==HabitTaskTemplates.recoveryPause.title){await _route(const RecoveryPausePage());return;}
    await _route(HabitStudyTimerPage(task:task));
  }
  Future<void> _startFocus()async{
    final active=ref.read(habitStudyTimerProvider);
    final tasks=ref.read(habitTasksProvider).tasks;
    final existing=tasks.where((t)=>t.id==active?.taskId).firstOrNull;
    if(existing!=null){await _resumeTask(existing);return;}
    try{
      final notifier=ref.read(habitTasksProvider.notifier);
      final pending=tasks.where((t)=>!t.faithSpecific&&t.source!=HabitTaskSource.coach&&
        (t.type==HabitTaskType.studySession||t.type==HabitTaskType.readingTimer)&&HabitIntegrityPolicy.isPersonalDashboardTask(t)&&
        HabitIntegrityPolicy.pending(t,ref.read(habitTasksProvider).completions,DateTime.now())).toList();
      String? linked;
      if(pending.isNotEmpty){
        linked=await showDialog<String>(context:context,builder:(ctx)=>SimpleDialog(title:const Text('Vincular concentración'),children:[
          SimpleDialogOption(onPressed:()=>Navigator.pop(ctx,'independent'),child:const Text('Sesión independiente')),
          for(final t in pending)SimpleDialogOption(onPressed:()=>Navigator.pop(ctx,t.id),child:Text(t.title)),
        ]));
        if(linked==null||!mounted)return;
        if(linked!='independent'){
          final selected=pending.firstWhere((t)=>t.id==linked);
          await _route(HabitStudyTimerPage(task:selected,focusMinutes:_focus,notifyOnEnd:_notifyFocus));return;
        }
      }
      final task=tasks.where((t)=>t.sourceReference=='template:focus:$_focus').firstOrNull??
        await notifier.createTask(title:'Sesión de enfoque',category:'Enfoque',type:HabitTaskType.studySession,
          targetMinutes:_focus,recurrence:HabitRecurrenceType.once,sourceReference:'template:focus:$_focus');
      if(mounted)await _route(HabitStudyTimerPage(task:task,focusMinutes:_focus,notifyOnEnd:_notifyFocus));
    }catch(_){_message('No se pudo iniciar la sesión.');}
  }
  Future<void> _discardActive()async{
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Descartar sesión activa'),
      content:const Text('No se registrarán sus minutos. Los registros ya guardados no cambian.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Descartar'))]));
    if(ok==true&&mounted)await ref.read(habitStudyTimerProvider.notifier).clear();
  }
  List<Widget> _focusPanel()=>[
    _heading('Sesión de enfoque'),
    if(ref.watch(habitStudyTimerProvider)!=null)...[
      PremiumCard(child:Column(children:[
        const ListTile(title:Text('Tienes una sesión activa'),subtitle:Text('Retómala antes de iniciar otra.')),
        Wrap(spacing:8,children:[TextButton(onPressed:_startFocus,child:const Text('Retomar')),TextButton(onPressed:_discardActive,child:const Text('Descartar'))]),
      ])),_gap(),
    ],
    PremiumCard(child:Column(children:[
      Icon(Icons.timer_outlined,size:36,color:Theme.of(context).colorScheme.primary),
      const SizedBox(height:8),Text('$_focus:00',style:Theme.of(context).textTheme.displaySmall),
      Wrap(spacing:8,children:[for(final m in [15,25,50])ChoiceChip(label:Text('$m min'),selected:_focus==m,onSelected:(_)=>setState(()=>_focus=m))]),
      Text('Descanso sugerido · ${_focus==50?10:5} min'),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Avisarme al terminar'),value:_notifyFocus,onChanged:(v)async{
        if(v&&!await FocusTimerNotificationService.requestPermission()){_message('No se pudo activar el aviso. Revisa los permisos.');return;}
        if(mounted)setState(()=>_notifyFocus=v);
      }),
      const SizedBox(height:12),FilledButton.icon(onPressed:_startFocus,icon:const Icon(Icons.play_arrow),label:const Text('Iniciar concentración')),
    ])),_gap(),
    _heading('Bienestar personal'),
    PremiumCard(child:Column(children:[
      ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.bedtime_outlined),title:const Text('Rutina nocturna'),
        subtitle:const Text('Preparar el descanso'),trailing:const Icon(Icons.chevron_right),onTap:()=>_route(const WindDownPage())),
      const Divider(height:1),
      ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.air),title:const Text('Respiración guiada'),
        subtitle:const Text('Una pausa breve'),trailing:const Icon(Icons.chevron_right),onTap:()=>_route(const WindDownPage(breathingOnly:true))),
      const Divider(height:1),
      ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.shield_outlined),title:const Text('Pausa personal'),
        subtitle:const Text('Apoyo ante momentos difíciles'),trailing:const Icon(Icons.chevron_right),onTap:()=>_route(const RecoveryPausePage())),
      const Divider(height:1),
      ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.edit_note),title:const Text('Diario privado'),
        trailing:const Icon(Icons.chevron_right),onTap:()=>_route(const PrivateJournalPage())),
    ])),_gap(),
    TextButton.icon(onPressed:()async{
      final task=await ref.read(habitTasksProvider.notifier).ensureTemplate(HabitTaskTemplates.windDown10Minutes);
      if(mounted)await _reminder(task);
    },icon:const Icon(Icons.notifications_none),label:const Text('Recordatorio nocturno')),
  ];
  @override
  Widget build(BuildContext context){
    ref.watch(coachTaskLazySyncProvider);
    final tasks=ref.watch(visibleHabitTasksProvider).where(HabitIntegrityPolicy.isPersonalDashboardTask).toList();
    final rows=ref.watch(habitTasksProvider).completions;
    final now=DateTime.now();
    return Scaffold(appBar:AppBar(title:const Text('Hábitos & Lectura')),
      body:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(16,8,16,8),child:Row(children:[
          for(final (i,label) in ['Hábitos','Lectura','Enfoque'].indexed)Expanded(child:Padding(
            padding:const EdgeInsets.symmetric(horizontal:2),child:ChoiceChip(label:Text(label),selected:_tab==i,onSelected:(_)=>setState(()=>_tab=i)))),
        ])),
        Expanded(child:ListView(key:PageStorageKey('habit_tab_$_tab'),padding:SecondaryScreenInsets.scrollPadding(context,const EdgeInsets.fromLTRB(16,8,16,24)),
          children:_tab==0?_habits(tasks,rows,now):_tab==1?_reading(now):_focusPanel())),
      ]),
    );
  }
}
