import 'package:gym_tracker/core/layout/mobile_content_frame.dart';
import 'dart:async';

import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/habit_study_timer_provider.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/private_journal_repository.dart';

class HabitStudyTimerPage extends ConsumerStatefulWidget {
  final HabitTask task;
  final int? focusMinutes;
  final bool notifyOnEnd;

  const HabitStudyTimerPage({
    super.key,
    required this.task,
    this.focusMinutes,
    this.notifyOnEnd=false,
  });

  @override
  ConsumerState<HabitStudyTimerPage> createState() =>
      _HabitStudyTimerPageState();
}

class _HabitStudyTimerPageState
    extends ConsumerState<HabitStudyTimerPage> {
  Timer? _ticker;
  final TextEditingController _noteController = TextEditingController();
  late final TextEditingController _referenceController;
  bool _bootstrapped = false;
  bool _finishing = false;
  bool _stoppingAtGoal=false;

  @override
  void initState() {
    super.initState();
    _referenceController = TextEditingController(text: widget.task.reference);
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() {});
          final current=ref.read(habitStudyTimerProvider);
          if(current!=null&&current.taskId==widget.task.id&&current.focusMode&&current.isRunning&&current.isCompleteAt(DateTime.now())&&!_stoppingAtGoal){
            _stoppingAtGoal=true;
            unawaited(ref.read(habitStudyTimerProvider.notifier).pause().whenComplete(()=>_stoppingAtGoal=false));
          }
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped || !mounted) return;
    _bootstrapped = true;

    final current = ref.read(habitStudyTimerProvider);
    if (current != null && current.taskId == widget.task.id) return;

    if (current != null && current.taskId != widget.task.id) {
      final discard=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('Hay otra sesión activa'),content:const Text('Puedes volver a la sesión anterior o descartarla expresamente.'),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Volver')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Descartar sesión'))]));
      if(!mounted)return;
      if(discard!=true){Navigator.pop(context);return;}
      await ref.read(habitStudyTimerProvider.notifier).clear();
    }

    await ref.read(habitStudyTimerProvider.notifier).start(
          taskId: widget.task.id,
          targetMinutes: widget.focusMinutes??widget.task.targetMinutes,
          focusMode:widget.focusMinutes!=null||widget.task.sourceReference.startsWith('template:focus:'),
          notifyOnEnd:widget.notifyOnEnd,
        );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _noteController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final timer = ref.read(habitStudyTimerProvider);
    if (timer == null || timer.taskId != widget.task.id || (timer.focusMode&&timer.isCompleteAt(DateTime.now()))) return;
    if (timer.isRunning) {
      await ref.read(habitStudyTimerProvider.notifier).pause();
    } else {
      await ref.read(habitStudyTimerProvider.notifier).resume();
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    final timer = ref.read(habitStudyTimerProvider);
    if (timer == null || timer.taskId != widget.task.id) return;

    setState(() => _finishing = true);
    try {
      final now = DateTime.now();
      final elapsedSeconds = timer.focusMode&&timer.targetSeconds>0?timer.elapsedSecondsAt(now).clamp(0,timer.targetSeconds).toInt():timer.elapsedSecondsAt(now);
      final minutes = elapsedSeconds ~/ 60;
      final id=timer.sessionId.isEmpty?'study:${widget.task.id}:${timer.updatedAt.toIso8601String()}':'study:${timer.sessionId}';
      if(_noteController.text.trim().isNotEmpty){await PrivateJournalRepository().put(_noteController.text,kind:'Sesión de enfoque',id:id);}

      final reference = _referenceController.text.trim();
      if (reference != widget.task.reference) {
        await ref.read(habitTasksProvider.notifier).updateTask(
              widget.task.copyWith(reference: reference),
            );
      }
      await ref.read(habitTasksProvider.notifier).completeTask(
            taskId: widget.task.id,
            minutesSpent: minutes,
            completedAt: now,
            completionId: id,
            status:elapsedSeconds>0?HabitTaskCompletionStatus.completed:HabitTaskCompletionStatus.skipped,
          );
      await ref.read(habitStudyTimerProvider.notifier).clear();

      if (!mounted)return;
      if(timer.focusMode&&!widget.task.sourceReference.startsWith('template:focus:break:')&&elapsedSeconds>=timer.targetSeconds){
        final rest=timer.targetSeconds>=3000?10:5;
        final startBreak=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Sesión guardada'),content:Text('¿Quieres descansar $rest minutos?'),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Terminar')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Iniciar descanso'))]));
        if(!mounted)return;
        if(startBreak==true){
          final key='template:focus:break:$rest';
          final notifier=ref.read(habitTasksProvider.notifier);
          final task=ref.read(habitTasksProvider).tasks.where((t)=>t.sourceReference==key).firstOrNull??await notifier.createTask(title:'Descanso de enfoque',category:'Enfoque',type:HabitTaskType.studySession,targetMinutes:rest,sourceReference:key);
          if(mounted)Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder:(_)=>HabitStudyTimerPage(task:task,focusMinutes:rest,notifyOnEnd:timer.notifyOnEnd)));
          return;
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo guardar. La sesión sigue disponible si aún está activa.')));
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(habitStudyTimerProvider);
    final now = DateTime.now();

    final elapsed = timer?.taskId == widget.task.id
        ? timer!.elapsedSecondsAt(now)
        : 0;
    final targetSeconds = timer?.taskId==widget.task.id?timer!.targetSeconds:(widget.focusMinutes??widget.task.targetMinutes)*60;
    final remaining = targetSeconds <= 0
        ? 0
        : (targetSeconds - elapsed).clamp(0, targetSeconds).toInt();
    final progress = targetSeconds <= 0
        ? 0.0
        : (elapsed / targetSeconds).clamp(0.0, 1.0).toDouble();
    final running = timer?.taskId == widget.task.id && timer!.isRunning;

    return Scaffold(
      appBar: AppBar(title: Text(widget.task.title)),
      body: SafeArea(bottom: false, 
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: SecondaryScreenInsets.scrollPadding(context, const EdgeInsets.all(24)),
              children: [
                Text(
                  widget.task.category,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  targetSeconds > 0
                      ? _formatSeconds(remaining)
                      : _formatSeconds(elapsed),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  targetSeconds > 0
                      ? 'de ${targetSeconds~/60} min'
                      : 'tiempo de estudio',
                  textAlign: TextAlign.center,
                ),
                if (targetSeconds > 0) ...[
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ],
                if (widget.task.faithSpecific) ...[
                  const SizedBox(height: 24),
                  TextField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Libro / capítulo o pasaje (opcional)',
                      hintText: 'Ej.: Juan 3 o Salmos 23',
                      prefixIcon: Icon(Icons.bookmark_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                TextField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Nota privada (opcional)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: timer?.taskId != widget.task.id || (timer?.focusMode==true&&remaining==0) ? null : _toggle,
                  icon: Icon(
                    running
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(running ? 'Pausar' : 'Continuar'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _finishing || timer?.taskId != widget.task.id ? null : _finish,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    _finishing ? 'Guardando…' : 'Finalizar sesión',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'El tiempo se conserva si sales de la pantalla. Las notas se guardan en el diario privado.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSeconds(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = safe ~/ 60;
    final seconds = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
