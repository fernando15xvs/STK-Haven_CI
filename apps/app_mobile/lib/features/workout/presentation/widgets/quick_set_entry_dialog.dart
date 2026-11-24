import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/domain/models/workout_session.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuickSetEntryDialog {
  const QuickSetEntryDialog._();

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required int exerciseIndex,
    required WorkoutExercise exercise,
    required SettingsState settings,
  }) async {
    var setIndex = exercise.sets.indexWhere(
      (set) => set.setType == WorkoutSetType.working && !set.completed,
    );
    if (setIndex < 0) {
      setIndex = exercise.sets.indexWhere((set) => !set.completed);
    }
    if (setIndex < 0) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _QuickSetEntryDialogBody(
        exerciseIndex: exerciseIndex,
        setIndex: setIndex,
        exercise: exercise,
        settings: settings,
        initial: exercise.sets[setIndex],
      ),
    );
  }
}

class _QuickSetEntryDialogBody extends ConsumerStatefulWidget {
  const _QuickSetEntryDialogBody({
    required this.exerciseIndex,
    required this.setIndex,
    required this.exercise,
    required this.settings,
    required this.initial,
  });

  final int exerciseIndex;
  final int setIndex;
  final WorkoutExercise exercise;
  final SettingsState settings;
  final WorkoutSet initial;

  @override
  ConsumerState<_QuickSetEntryDialogBody> createState() =>
      _QuickSetEntryDialogBodyState();
}

class _QuickSetEntryDialogBodyState
    extends ConsumerState<_QuickSetEntryDialogBody> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  late final TextEditingController _rir;
  late final FocusNode _repsFocus;
  late final FocusNode _rirFocus;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final displayWeight = WeightConverter.displayWeight(
      widget.initial.weight,
      widget.settings.weightUnit,
    );
    _weight = TextEditingController(
      text: widget.initial.weight <= 0 ? '' : _number(displayWeight),
    );
    _reps = TextEditingController(
      text: widget.initial.reps <= 0 ? '' : '${widget.initial.reps}',
    );
    _rir = TextEditingController(
      text: widget.initial.rir == null ? '' : '${widget.initial.rir}',
    );
    _repsFocus = FocusNode();
    _rirFocus = FocusNode();
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _rir.dispose();
    _repsFocus.dispose();
    _rirFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final exercise = widget.exercise;

    return AlertDialog(
      title: Text(
        'Serie ${widget.setIndex + 1} · ${exercise.exerciseNameSnapshot}',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _weight,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Peso (${settings.weightUnit.label})',
                ),
                onSubmitted: (_) => _repsFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reps,
                focusNode: _repsFocus,
                keyboardType: TextInputType.number,
                textInputAction: settings.isRirEnabled
                    ? TextInputAction.next
                    : TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Repeticiones'),
                onSubmitted: (_) {
                  if (settings.isRirEnabled) {
                    _rirFocus.requestFocus();
                  }
                },
              ),
              if (settings.isRirEnabled) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _rir,
                  focusNode: _rirFocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'RIR'),
                ),
              ],
              if (exercise.unilateral) ...[
                const SizedBox(height: 12),
                const Text(
                  'En unilateral estos valores quedan como entrada base. Marca Izquierda/Derecha en el editor para guardar el rendimiento real de cada lado.',
                ),
              ],
              if (_validationMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: Icon(
            exercise.unilateral ? Icons.save_outlined : Icons.check_rounded,
          ),
          label: Text(
            exercise.unilateral ? 'Guardar valores' : 'Completar serie',
          ),
        ),
      ],
    );
  }

  void _save() {
    final typedWeight =
        double.tryParse(_weight.text.trim().replaceAll(',', '.')) ?? 0;
    final canonicalWeight = WeightConverter.toCanonicalKg(
      typedWeight,
      widget.settings.weightUnit,
    );
    final typedReps = int.tryParse(_reps.text.trim()) ?? 0;
    final typedRir = int.tryParse(_rir.text.trim());

    if (canonicalWeight <= 0 || typedReps <= 0) {
      setState(() {
        _validationMessage = 'Ingresa peso y repeticiones válidos.';
      });
      return;
    }

    ref.read(activeWorkoutProvider.notifier).updateSet(
          widget.exerciseIndex,
          widget.setIndex,
          widget.initial.copyWith(
            weight: canonicalWeight,
            reps: typedReps,
            rir: typedRir,
            clearRir: _rir.text.trim().isEmpty,
            completed: widget.exercise.unilateral ? false : true,
          ),
        );
    Navigator.pop(context);
  }

  static String _number(double value) => value % 1 == 0
      ? '${value.toInt()}'
      : value.toStringAsFixed(1);
}
