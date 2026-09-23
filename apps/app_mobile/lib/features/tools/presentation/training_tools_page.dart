import 'dart:async';

import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/exercise.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/tools/application/training_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/presentation/widgets/barbell_calculator_modal.dart';

class TrainingToolsPage extends ConsumerStatefulWidget {
  final Exercise? initialExercise;
  final String? initialExerciseId;
  final double? initialWeightKg;
  final int? initialReps;

  const TrainingToolsPage({
    super.key,
    this.initialExercise,
    this.initialExerciseId,
    this.initialWeightKg,
    this.initialReps,
  });

  @override
  ConsumerState<TrainingToolsPage> createState() => _TrainingToolsPageState();
}

class _TrainingToolsPageState extends ConsumerState<TrainingToolsPage> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;
  int _timerSeconds = 90;
  int _remaining = 90;
  bool _running = false;
  Timer? _timer;
  String? _exerciseId;

  @override
  void initState() {
    super.initState();
    _exerciseId = widget.initialExercise?.id ?? widget.initialExerciseId;
    final settings = ref.read(settingsProvider);
    final initialDisplayWeight = widget.initialWeightKg == null
        ? 60.0
        : WeightConverter.displayWeight(
            widget.initialWeightKg!,
            settings.weightUnit,
          );
    _weightController = TextEditingController(
      text: _number(initialDisplayWeight),
    );
    _repsController = TextEditingController(
      text: '${widget.initialReps ?? 8}',
    );
  }

  String _number(double value) => value % 1 == 0
      ? '${value.toInt()}'
      : value.toStringAsFixed(1);

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

  void _resetTimer([int? seconds]) {
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
    for (final item in exercises) {
      if (item.id == _exerciseId) selected = item;
    }
    final advice =
        selected == null ? null : ExerciseToolAdvisor.forExercise(selected);
    final typedWeight =
        double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    final canonicalKg =
        WeightConverter.toCanonicalKg(typedWeight, settings.weightUnit);
    final oneRmKg = OneRmCalculator.estimate(weight: canonicalKg, reps: reps);
    final percentages = OneRmCalculator.percentageTable(oneRmKg);

    return Scaffold(
      appBar: AppBar(title: const Text('Herramientas')),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          Text('CENTRO DE ENTRENAMIENTO', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          Text(
            'Calcula intensidad, controla tiempos y abre la herramienta adecuada para cada ejercicio.',
            style: AppTypography.bodyMedium,
          ),
          if (widget.initialWeightKg != null || widget.initialReps != null) ...[
            const SizedBox(height: 8),
            Text(
              'Valores precargados desde el ejercicio activo; puedes modificarlos sin alterar la serie.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _Panel(
            title: 'Accesos inteligentes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _exerciseId,
                  decoration: const InputDecoration(labelText: 'Ejercicio'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin ejercicio específico'),
                    ),
                    ...exercises.map(
                      (exercise) => DropdownMenuItem<String?>(
                        value: exercise.id,
                        child: Text(
                          exercise.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _exerciseId = value),
                ),
                if (advice != null) ...[
                  const SizedBox(height: 12),
                  Text(advice.reason, style: AppTypography.bodySmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: advice.primary
                        .map(
                          (kind) => ActionChip(
                            avatar: Icon(_iconFor(kind), size: 18),
                            label: Text(_labelFor(kind)),
                            onPressed: () {
                              if (kind == TrainingToolKind.plates) {
                                showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  builder: (_) => const BarbellCalculatorModal(),
                                );
                              } else if (kind == TrainingToolKind.timer) {
                                _resetTimer(90);
                              }
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Panel(
            title: 'Calculadora 1RM',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Peso (${settings.weightUnit.name})',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _repsController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Repeticiones'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    oneRmKg > 0
                        ? '1RM estimado: ${WeightConverter.formatWeight(oneRmKg, settings.weightUnit)}'
                        : 'Ingresa peso y repeticiones válidos',
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (percentages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...percentages.entries.take(6).map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(child: Text('${entry.key}%')),
                              Text(
                                WeightConverter.formatWeight(
                                  entry.value,
                                  settings.weightUnit,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Panel(
            title: 'Temporizador independiente',
            child: Column(
              children: [
                Text(
                  _formatSeconds(_remaining),
                  style: AppTypography.displayMedium.copyWith(
                    color: _remaining == 0
                        ? AppColors.success
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [60, 90, 120, 180]
                      .map(
                        (seconds) => ChoiceChip(
                          label: Text('${seconds}s'),
                          selected: _timerSeconds == seconds,
                          onSelected: (_) => _resetTimer(seconds),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _toggleTimer,
                        icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                        label: Text(_running ? 'Pausar' : 'Iniciar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _resetTimer(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reiniciar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => const BarbellCalculatorModal(),
            ),
            icon: const Icon(Icons.fitness_center),
            label: const Text('Abrir calculadora de discos'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static String _formatSeconds(int total) =>
      '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';

  static String _labelFor(TrainingToolKind kind) => switch (kind) {
        TrainingToolKind.oneRm => '1RM',
        TrainingToolKind.timer => 'Temporizador',
        TrainingToolKind.plates => 'Discos',
      };

  static IconData _iconFor(TrainingToolKind kind) => switch (kind) {
        TrainingToolKind.oneRm => Icons.calculate_outlined,
        TrainingToolKind.timer => Icons.timer_outlined,
        TrainingToolKind.plates => Icons.fitness_center,
      };
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: AppRadius.lg_,
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.headlineMedium),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}
