import 'dart:async';

import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/application/habit_study_timer_provider.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HabitStudyTimerPage extends ConsumerStatefulWidget {
  final HabitTask task;

  const HabitStudyTimerPage({
    super.key,
    required this.task,
  });

  @override
  ConsumerState<HabitStudyTimerPage> createState() =>
      _HabitStudyTimerPageState();
}

class _HabitStudyTimerPageState
    extends ConsumerState<HabitStudyTimerPage> {
  Timer? _ticker;
  final TextEditingController _noteController = TextEditingController();
  bool _bootstrapped = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
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
      await ref.read(habitStudyTimerProvider.notifier).clear();
    }

    await ref.read(habitStudyTimerProvider.notifier).start(
          taskId: widget.task.id,
          targetMinutes: widget.task.targetMinutes,
        );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final timer = ref.read(habitStudyTimerProvider);
    if (timer == null) return;
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
      final elapsedSeconds = timer.elapsedSecondsAt(now);
      final minutes = elapsedSeconds <= 0 ? 0 : (elapsedSeconds + 59) ~/ 60;

      await ref.read(habitTasksProvider.notifier).completeTask(
            taskId: widget.task.id,
            minutesSpent: minutes,
            note: _noteController.text,
            completedAt: now,
          );
      await ref.read(habitStudyTimerProvider.notifier).clear();

      if (mounted) Navigator.of(context).pop();
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
    final targetSeconds = widget.task.targetMinutes * 60;
    final remaining = targetSeconds <= 0
        ? 0
        : (targetSeconds - elapsed).clamp(0, targetSeconds).toInt();
    final progress = targetSeconds <= 0
        ? 0.0
        : (elapsed / targetSeconds).clamp(0.0, 1.0).toDouble();
    final running = timer?.taskId == widget.task.id && timer!.isRunning;

    return Scaffold(
      appBar: AppBar(title: Text(widget.task.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(24),
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
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  targetSeconds > 0
                      ? 'de ${widget.task.targetMinutes} min'
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
                if (widget.task.reference.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.bookmark_outline),
                      title: const Text('Referencia'),
                      subtitle: Text(widget.task.reference),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                TextField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Nota o reflexión (opcional)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: timer == null ? null : _toggle,
                  icon: Icon(
                    running
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(running ? 'Pausar' : 'Continuar'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _finishing ? null : _finish,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    _finishing ? 'Guardando…' : 'Finalizar sesión',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'El tiempo usa marcas de tiempo reales, por lo que continúa correctamente si la app pasa a segundo plano.',
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
