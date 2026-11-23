import 'package:core/features/profile/application/unilateral_rest_choices.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Reused by routine setup and the in-workout unilateral editor.
/// Zero belongs to the "Directo" mode and is handled by the parent; positive
/// durations are displayed and customized here without changing saved data.
class UnilateralPauseDurationField extends StatelessWidget {
  const UnilateralPauseDurationField({
    super.key,
    required this.seconds,
    required this.onChanged,
    required this.keyPrefix,
  });

  final int seconds;
  final ValueChanged<int> onChanged;
  final String keyPrefix;

  static String formatSeconds(int value) {
    if (value < 60) return '$value s';
    final minutes = value ~/ 60;
    final seconds = value % 60;
    return seconds == 0
        ? '$minutes min'
        : '$minutes min $seconds s';
  }

  Future<void> _customize(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    var text = '$seconds';
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Pausa entre lados', style: AppTypography.headlineMedium),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: text,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Duración en segundos',
              helperText: 'Entre 1 s y 10 min',
            ),
            onChanged: (value) => text = value,
            validator: (value) {
              final parsed = int.tryParse((value ?? '').trim());
              if (parsed == null || parsed < 1 || parsed > 600) {
                return 'Introduce entre 1 y 600 segundos';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, int.parse(text.trim()));
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (context.mounted && result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final options = <int>{
      15,
      ...UnilateralRestChoices.forSelected(seconds),
      seconds,
    }.where((value) => value > 0).toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('${keyPrefix}_duration_$seconds'),
          initialValue: seconds,
          decoration: const InputDecoration(
            labelText: 'Pausa antes del otro lado',
          ),
          items: options.map((value) => DropdownMenuItem<int>(
            value: value,
            child: Text(formatSeconds(value)),
          )).toList(growable: false),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: ValueKey('${keyPrefix}_custom'),
            onPressed: () => _customize(context),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Personalizar'),
          ),
        ),
      ],
    );
  }
}
