import 'dart:async';

import 'package:core/features/habits/application/habit_task_templates.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecoveryPausePage extends ConsumerStatefulWidget {
  const RecoveryPausePage({super.key});

  @override
  ConsumerState<RecoveryPausePage> createState() => _RecoveryPausePageState();
}

class _RecoveryPausePageState extends ConsumerState<RecoveryPausePage> {
  final TextEditingController _trigger = TextEditingController();
  Timer? _timer;
  int _elapsedSeconds = 0;
  double _urge = 5;
  String _nextAction = 'Caminar 10 minutos';
  bool _running = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_running) return;
      setState(() => _elapsedSeconds += 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _trigger.dispose();
    super.dispose();
  }

  bool get _inhale => (_elapsedSeconds % 10) < 4;

  Future<String> _ensureTask() async {
    final state = ref.read(habitTasksProvider);
    for (final task in state.tasks) {
      if (!task.archived &&
          task.title == HabitTaskTemplates.recoveryPause.title) {
        return task.id;
      }
    }
    final task = await ref
        .read(habitTasksProvider.notifier)
        .createFromTemplate(HabitTaskTemplates.recoveryPause);
    return task.id;
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final taskId = await _ensureTask();
      final note = <String>[
        'Intensidad inicial: ${_urge.round()}/10.',
        if (_trigger.text.trim().isNotEmpty)
          'Disparador: ${_trigger.text.trim()}',
        'Siguiente acción: $_nextAction.',
      ].join(' ');
      await ref.read(habitTasksProvider.notifier).completeTask(
            taskId: taskId,
            minutesSpent:
                _elapsedSeconds <= 0 ? 0 : (_elapsedSeconds / 60).ceil(),
            note: note,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const actions = <String>[
      'Caminar 10 minutos',
      'Ducharme',
      'Tomar agua',
      'Alejar el teléfono',
      'Hablar con alguien de confianza',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Pausa de recuperación')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'No decidas en el pico del impulso',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Retrasa la acción unos minutos, respira y elige una respuesta '
              'concreta. Esto es apoyo personal y no sustituye tratamiento '
              'profesional.',
            ),
            const SizedBox(height: 24),
            Text('Intensidad del impulso: ${_urge.round()}/10'),
            Slider(
              value: _urge,
              min: 0,
              max: 10,
              divisions: 10,
              label: '${_urge.round()}',
              onChanged: (value) => setState(() => _urge = value),
            ),
            const SizedBox(height: 16),
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 900),
                width: _inhale ? 165 : 120,
                height: _inhale ? 165 : 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context)
                      .colorScheme
                      .secondaryContainer,
                ),
                alignment: Alignment.center,
                child: Text(
                  _inhale ? 'Inhala\n4 s' : 'Exhala\n6 s',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _running = !_running),
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                label: Text(_running ? 'Pausar respiración' : 'Continuar'),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _trigger,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '¿Qué disparó este momento? (opcional)',
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Elige qué harás durante los próximos 10 minutos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions
                  .map(
                    (action) => ChoiceChip(
                      label: Text(action),
                      selected: _nextAction == action,
                      onSelected: (_) => setState(() => _nextAction = action),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _finish,
              icon: const Icon(Icons.shield_outlined),
              label: Text(_saving ? 'Guardando…' : 'Guardar esta pausa'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Si hay riesgo inmediato, síntomas de abstinencia peligrosos o '
              'sientes que no puedes mantenerte a salvo, busca atención '
              'profesional o de emergencia.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
