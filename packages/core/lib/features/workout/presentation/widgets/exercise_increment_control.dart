import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Load increments are saved in canonical kg regardless of the display unit.
class ExerciseIncrementControl extends ConsumerWidget {
  final String exerciseId;
  const ExerciseIncrementControl({super.key, required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final configured = settings.exerciseIncrementsKg[exerciseId];
    final display = WeightConverter.displayWeight(
      configured ?? settings.defaultIncrement, settings.weightUnit,
    );
    final shown = display.toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _IncrementDialog(
            exerciseId: exerciseId,
            unit: settings.weightUnit,
            initialValue: display,
          ),
        ),
        icon: const Icon(Icons.tune, size: 18),
        label: Text(
          'Salto de carga: $shown ${settings.weightUnit.label}'
          '${configured == null ? ' (perfil)' : ' (ejercicio)'}',
        ),
      ),
    );
  }
}

class _IncrementDialog extends ConsumerStatefulWidget {
  final String exerciseId;
  final WeightUnit unit;
  final double initialValue;
  const _IncrementDialog({
    required this.exerciseId,
    required this.unit,
    required this.initialValue,
  });
  @override
  ConsumerState<_IncrementDialog> createState() => _IncrementDialogState();
}

class _IncrementDialogState extends ConsumerState<_IncrementDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue.toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), ''),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final typed = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    final kg = typed == null ? null :
        WeightConverter.toCanonicalKg(typed, widget.unit);
    if (kg == null || !kg.isFinite || kg <= 0 || kg > 100) {
      setState(() => _error = 'Introduce un incremento válido y positivo.');
      return;
    }
    ref.read(settingsProvider.notifier)
        .setExerciseIncrement(widget.exerciseId, typed!, widget.unit);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Salto de peso por ejercicio'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Indica el incremento real de polea, máquina, '
            'mancuerna o discos. Solo cambia este ejercicio.'),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Incremento (${widget.unit.label})',
            errorText: _error,
          ),
          onSubmitted: (_) => _save(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () {
          ref.read(settingsProvider.notifier)
              .setExerciseIncrement(widget.exerciseId, null, widget.unit);
          Navigator.of(context).pop();
        },
        child: const Text('Usar valor del perfil'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _save, child: const Text('Guardar')),
    ],
  );
}
