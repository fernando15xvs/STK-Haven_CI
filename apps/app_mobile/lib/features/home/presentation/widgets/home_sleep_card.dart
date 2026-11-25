import 'package:core/features/recovery/application/sleep_diary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:intl/intl.dart';

String _duration(int minutes) => '${minutes ~/ 60} h ${minutes % 60} min';

class HomeSleepCard extends ConsumerWidget {
  const HomeSleepCard({super.key,required this.now});
  final DateTime now;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary=ref.watch(sleepDiaryProvider);
    final minutes=diary.minutesFor(now), goal=diary.goalMinutes;
    final colors=AppColors.of(context);
    return PremiumCard(
      key:const ValueKey('home_sleep_card'),
      padding: const EdgeInsets.symmetric(horizontal:AppSpacing.md,vertical:AppSpacing.sm),
      onTap:()=>showModalBottomSheet<void>(context:context,isScrollControlled:true,useSafeArea:true,
        showDragHandle:true,builder:(_)=>_SleepSheet(today:now)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Icon(Icons.bedtime_outlined,color:colors.primary,size:24),
          const SizedBox(width:AppSpacing.sm),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Descanso nocturno',style:AppTypography.bodyMedium.copyWith(fontWeight:FontWeight.w600)),
            Text(minutes==null?'Registrar horas de sueño':[
              _duration(minutes),if(goal!=null)'Meta: ${_duration(goal)}','Registro manual',
            ].join(' · '),style:AppTypography.bodySmall.copyWith(color:colors.textSecondary)),
          ])),
          Icon(Icons.chevron_right,color:colors.textSecondary),
        ]),
        if(minutes!=null && goal!=null)...[
          const SizedBox(height:AppSpacing.xs),
          ClipRRect(borderRadius:AppRadius.sm_,child:LinearProgressIndicator(
            value:(minutes/goal).clamp(0.0,1.0).toDouble(),minHeight:5,
            semanticsLabel:'Duración de sueño respecto a tu meta personal')),
        ],
      ]),
    );
  }
}

class _SleepSheet extends ConsumerStatefulWidget {
  const _SleepSheet({required this.today});
  final DateTime today;
  @override
  ConsumerState<_SleepSheet> createState()=>_SleepSheetState();
}
class _SleepSheetState extends ConsumerState<_SleepSheet> {
  bool _busy=false;
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    if(_busy)return;
    setState((){_busy=true;_error=null;});
    try {await action();}
    catch(_){if(mounted)setState(()=>_error='No se pudo guardar. Inténtalo de nuevo.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<int?> _durationDialog(String title,int? initial,{bool goal=false}) async {
    var hours=(initial??0)~/60;
    var minutes=(initial??0)%60;
    final form=GlobalKey<FormState>();
    return showDialog<int>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(title),
      content:Form(key:form,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextFormField(initialValue:'$hours',keyboardType:TextInputType.number,
          decoration:const InputDecoration(labelText:'Horas'),
          validator:(v){final n=int.tryParse(v??'');return n==null||n<0||n>24?'0 a 24':null;},
          onChanged:(v)=>hours=int.tryParse(v)??-1),
        const SizedBox(height:AppSpacing.xs),
        TextFormField(initialValue:'$minutes',keyboardType:TextInputType.number,
          decoration:const InputDecoration(labelText:'Minutos'),
          validator:(v){final n=int.tryParse(v??'');return n==null||n<0||n>59?'0 a 59':null;},
          onChanged:(v)=>minutes=int.tryParse(v)??-1),
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),
        FilledButton(onPressed:(){
          if(!(form.currentState?.validate()??false))return;
          final total=hours*60+minutes;
          if(total>1440 || (goal&&total==0)){
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Revisa la duración.')));
            return;
          }
          Navigator.pop(ctx,total);
        },child:const Text('Guardar')),
      ],
    ));
  }
  Future<void> _edit(DateTime date) async {
    final value=await _durationDialog('Horas de sueño · ${DateFormat('dd/MM').format(date)}',
      ref.read(sleepDiaryProvider).minutesFor(date));
    if(value==null||!mounted)return;
    await _run(()=>ref.read(sleepDiaryProvider.notifier).saveNight(date,value));
  }
  @override
  Widget build(BuildContext context) {
    final diary=ref.watch(sleepDiaryProvider);
    return SafeArea(top:false,child:ConstrainedBox(
      constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(context).height*.8),
      child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(16,0,16,24),child:Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('Sueño y descanso',style:AppTypography.headlineLarge),
          const Text('Anota la duración de la noche en la fecha en que despertaste. La calidad del sueño se valora en tu check-in.'),
          const SizedBox(height:AppSpacing.sm),
          FilledButton.icon(onPressed:_busy?null:()=>_edit(widget.today),
            icon:const Icon(Icons.edit_outlined),label:const Text('Registrar anoche')),
          TextButton(onPressed:_busy?null:()async{
            final today=widget.today;
            final date=await showDatePicker(context:context,initialDate:today,
              firstDate:DateTime(today.year-10),lastDate:today);
            if(date!=null&&mounted)await _edit(date);
          },child:const Text('Registrar otra fecha')),
          ListTile(contentPadding:EdgeInsets.zero,title:const Text('Meta personal'),
            subtitle:Text(diary.goalMinutes==null?'Sin meta configurada':_duration(diary.goalMinutes!)),
            onTap:_busy?null:()async{
              final value=await _durationDialog('Meta personal',diary.goalMinutes,goal:true);
              if(value!=null&&mounted)await _run(()=>ref.read(sleepDiaryProvider.notifier).setGoal(value));
            },
            trailing:diary.goalMinutes==null?const Icon(Icons.chevron_right):IconButton(
              tooltip:'Quitar meta de sueño',onPressed:_busy?null:()=>_run(()=>ref.read(sleepDiaryProvider.notifier).setGoal(null)),
              icon:const Icon(Icons.close))),
          const Divider(),
          Text('Últimos registros',style:AppTypography.headlineSmall),
          if(diary.entries.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('Todavía no tienes registros de sueño.')),
          for(final row in diary.recent())
            ListTile(contentPadding:EdgeInsets.zero,title:Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(row.key))),
              subtitle:Text(_duration(row.value)),
              onTap:_busy?null:()=>_edit(DateTime.parse(row.key)),
              trailing:IconButton(tooltip:'Eliminar registro de ${row.key}',icon:const Icon(Icons.delete_outline),
                onPressed:_busy?null:()async{
                  final confirm=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
                    title:const Text('Eliminar registro de sueño'),content:const Text('Se eliminará solo esta noche.'),
                    actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
                      FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Eliminar'))]));
                  if(confirm==true&&mounted)await _run(()=>ref.read(sleepDiaryProvider.notifier).deleteNight(DateTime.parse(row.key)));
                })),
          if(_error!=null)Text(_error!),
          if(_busy)const LinearProgressIndicator(),
        ],
      )),
    ));
  }
}
