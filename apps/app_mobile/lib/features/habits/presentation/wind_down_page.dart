import 'dart:async';

import 'package:core/features/habits/application/habit_task_templates.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WindDownPage extends ConsumerStatefulWidget {
  const WindDownPage({super.key});

  @override
  ConsumerState<WindDownPage> createState() => _WindDownPageState();
}

class _WindDownPageState extends ConsumerState<WindDownPage> {
  static const int _targetSeconds = 10 * 60;
  final TextEditingController _brainDump = TextEditingController();
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _running = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_running) return;
      setState(() {
        _elapsedSeconds =
            (_elapsedSeconds + 1).clamp(0, _targetSeconds).toInt();
        if (_elapsedSeconds >= _targetSeconds) _running = false;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _brainDump.dispose();
    super.dispose();
  }

  bool get _inhale => (_elapsedSeconds % 10) < 4;

  Future<String> _ensureTask() async {
    final state = ref.read(habitTasksProvider);
    for (final task in state.tasks) {
      if (!task.archived &&
          task.title == HabitTaskTemplates.windDown10Minutes.title) {
        return task.id;
      }
    }
    final task = await ref
        .read(habitTasksProvider.notifier)
        .createFromTemplate(HabitTaskTemplates.windDown10Minutes);
    return task.id;
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final taskId = await _ensureTask();
      final minutes = _elapsedSeconds <= 0
          ? 0
          : (_elapsedSeconds / 60).ceil();
      await ref.read(habitTasksProvider.notifier).completeTask(
            taskId: taskId,
            minutesSpent: minutes,
            note: _brainDump.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (_targetSeconds - _elapsedSeconds).clamp(0, _targetSeconds);
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;

    return Scaffold(
      appBar: AppBar(title: const Text('Bajar revoluciones')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Rutina nocturna · 10 min',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Baja el brillo y deja las decisiones para mañana. '
              'Esta sesión es para soltar tensión, no para hacerlo perfecto.',
            ),
            const SizedBox(height: 28),
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOut,
                width: _inhale ? 190 : 135,
                height: _inhale ? 190 : 135,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.75),
                ),
                alignment: Alignment.center,
                child: Text(
                  _inhale ? 'Inhala\n4 s' : 'Exhala\n6 s',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '${minutes.toString().padLeft(2, '0')}:'
                '${seconds.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _running = !_running),
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                label: Text(_running ? 'Pausar' : 'Continuar'),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _brainDump,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Descarga mental (opcional)',
                hintText:
                    'Escribe lo que no quieres seguir cargando esta noche.',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cuando termines, deja el teléfono fuera del alcance de la cama '
              'y mantén la habitación lo más oscura posible.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _finish,
              icon: const Icon(Icons.bedtime_outlined),
              label: Text(_saving ? 'Guardando…' : 'Terminar y descansar'),
            ),
          ],
        ),
      ),
    );
  }
}
