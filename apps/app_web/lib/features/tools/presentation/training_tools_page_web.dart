import 'dart:async';

import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/tools/application/training_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';

class TrainingToolsPageWeb extends ConsumerStatefulWidget {
  final Exercise? initialExercise;

  const TrainingToolsPageWeb({super.key, this.initialExercise});

  @override
  ConsumerState<TrainingToolsPageWeb> createState() => _TrainingToolsPageWebState();
}

class _TrainingToolsPageWebState extends ConsumerState<TrainingToolsPageWeb> {
  final _weightController = TextEditingController(text: '60');
  final _repsController = TextEditingController(text: '8');
  String? _exerciseId;
  int _timerSeconds = 90;
  int _remaining = 90;
  bool _running = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _exerciseId = widget.initialExercise?.id;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_remaining <= 0) _remaining = _timerSeconds;
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining <= 1) {
        timer.cancel();
        setState(() {
          _remaining = 0;
          _running = false;
        });
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _reset([int? seconds]) {
    _timer?.cancel();
    setState(() {
      if (seconds != null) _timerSeconds = seconds;
      _remaining = _timerSeconds;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exerciseListProvider);
    final settings = ref.watch(settingsProvider);
    Exercise? selected;
    for (final exercise in exercises) {
      if (exercise.id == _exerciseId) selected = exercise;
    }
    final advice = selected == null ? null : ExerciseToolAdvisor.forExercise(selected);
    final typedWeight = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    final oneRmKg = OneRmCalculator.estimate(
      weight: WeightConverter.toCanonicalKg(typedWeight, settings.weightUnit),
      reps: reps,
    );
    final table = OneRmCalculator.percentageTable(oneRmKg);

    return Scaffold(
      appBar: AppBar(title: const Text('Herramientas')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cards = <Widget>[
                _Panel(
                  title: 'Accesos inteligentes',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String?>(
                        initialValue: _exerciseId,
                        decoration: const InputDecoration(labelText: 'Ejercicio'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Sin ejercicio específico')),
                          ...exercises.map((exercise) => DropdownMenuItem<String?>(value: exercise.id, child: Text(exercise.name, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (value) => setState(() => _exerciseId = value),
                      ),
                      if (advice != null) ...[
                        const SizedBox(height: 12),
                        Text(advice.reason, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: advice.primary.map((kind) => Chip(avatar: Icon(_iconFor(kind), size: 18), label: Text(_labelFor(kind)))).toList()),
                      ],
                    ],
                  ),
                ),
                _Panel(
                  title: 'Calculadora 1RM',
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(child: TextField(controller: _weightController, decoration: InputDecoration(labelText: 'Peso (${settings.weightUnit.name})'), onChanged: (_) => setState(() {}))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: _repsController, decoration: const InputDecoration(labelText: 'Repeticiones'), onChanged: (_) => setState(() {}))),
                      ]),
                      const SizedBox(height: 16),
                      Align(alignment: Alignment.centerLeft, child: Text(oneRmKg > 0 ? '1RM estimado: ${WeightConverter.formatWeight(oneRmKg, settings.weightUnit)}' : 'Ingresa valores válidos', style: AppTypography.headlineMedium.copyWith(color: AppColors.primary))),
                      if (table.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...table.entries.take(6).map((entry) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text('${entry.key}%')), Text(WeightConverter.formatWeight(entry.value, settings.weightUnit))]))),
                      ],
                    ],
                  ),
                ),
                _Panel(
                  title: 'Temporizador independiente',
                  child: Column(
                    children: [
                      Text(_formatSeconds(_remaining), style: AppTypography.displayMedium),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, children: [60, 90, 120, 180].map((seconds) => ChoiceChip(label: Text('${seconds}s'), selected: _timerSeconds == seconds, onSelected: (_) => _reset(seconds))).toList()),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: FilledButton.icon(onPressed: _toggleTimer, icon: Icon(_running ? Icons.pause : Icons.play_arrow), label: Text(_running ? 'Pausar' : 'Iniciar'))),
                        const SizedBox(width: 10),
                        OutlinedButton(onPressed: () => _reset(), child: const Text('Reiniciar')),
                      ]),
                    ],
                  ),
                ),
              ];
              if (constraints.maxWidth < 760) {
                return ListView(padding: const EdgeInsets.all(16), children: cards.expand((card) => [card, const SizedBox(height: 16)]).toList());
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  cards[0],
                  const SizedBox(height: 18),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cards[1]), const SizedBox(width: 18), Expanded(child: cards[2])]),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }

  static String _formatSeconds(int total) => '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  static String _labelFor(TrainingToolKind kind) => switch (kind) {TrainingToolKind.oneRm => '1RM', TrainingToolKind.timer => 'Temporizador', TrainingToolKind.plates => 'Discos'};
  static IconData _iconFor(TrainingToolKind kind) => switch (kind) {TrainingToolKind.oneRm => Icons.calculate_outlined, TrainingToolKind.timer => Icons.timer_outlined, TrainingToolKind.plates => Icons.fitness_center};
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.lg_, border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTypography.headlineLarge), const SizedBox(height: 14), child]),
      );
}
