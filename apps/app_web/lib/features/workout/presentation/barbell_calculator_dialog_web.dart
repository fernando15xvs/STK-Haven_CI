import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/workout/application/barbell_calculator.dart';

import '../../../core/theme/app_colors.dart';

class BarbellCalculatorDialogWeb extends ConsumerStatefulWidget {
  final double? initialTargetWeight;

  const BarbellCalculatorDialogWeb({super.key, this.initialTargetWeight});

  static Future<void> show(BuildContext context, {double? initialTargetWeight}) {
    return showDialog<void>(
      context: context,
      builder: (_) => BarbellCalculatorDialogWeb(initialTargetWeight: initialTargetWeight),
    );
  }

  @override
  ConsumerState<BarbellCalculatorDialogWeb> createState() => _BarbellCalculatorDialogWebState();
}

class _BarbellCalculatorDialogWebState extends ConsumerState<BarbellCalculatorDialogWeb> {
  late final TextEditingController _controller;
  BarbellCalculatorResult? _result;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialTargetWeight != null && widget.initialTargetWeight! > 0
          ? _number(widget.initialTargetWeight!)
          : '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculate());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _number(double value) => value % 1 == 0 ? '${value.toInt()}' : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  void _calculate() {
    final target = double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;
    if (target <= 0) {
      setState(() => _result = null);
      return;
    }

    final unit = ref.read(settingsProvider).weightUnit;
    final isLb = unit == WeightUnit.lb;
    setState(() {
      _result = BarbellCalculator.calculate(
        targetWeight: target,
        barWeight: isLb ? 45 : 20,
        availablePlates: isLb
            ? const [45, 35, 25, 10, 5, 2.5]
            : const [25, 20, 15, 10, 5, 2.5, 1.25],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(settingsProvider).weightUnit;
    final result = _result;

    return AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: Row(
        children: [
          const Icon(Icons.calculate_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(child: Text('Calculadora de discos')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Peso total (${unit.label})',
                  prefixIcon: const Icon(Icons.monitor_weight_outlined),
                ),
                onChanged: (_) => _calculate(),
              ),
              const SizedBox(height: 18),
              if (result == null)
                Text('Ingresa el peso total que deseas cargar, incluyendo la barra.', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary))
              else ...[
                _InfoRow(label: 'Barra', value: '${_number(result.barWeight)} ${unit.label}'),
                _InfoRow(label: 'Peso alcanzado', value: '${_number(result.actualTotalWeight)} ${unit.label}'),
                const SizedBox(height: 12),
                Text('DISCOS POR LADO', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                if (result.platesPerSide.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.md_),
                    child: Text('No necesitas añadir discos.', style: AppTypography.bodyMedium),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: result.platesPerSide
                        .map(
                          (plate) => Chip(
                            avatar: const Icon(Icons.circle, size: 15),
                            label: Text('${_number(plate.weight)} ${unit.label}'),
                          ),
                        )
                        .toList(growable: false),
                  ),
                if (result.remainder.abs() > 0.001) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Con los discos disponibles faltan ${_number(result.remainder.abs())} ${unit.label} para llegar exactamente al objetivo.',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Verifica siempre el peso cargado y asegura los discos antes de usar la barra.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary))),
          Text(value, style: AppTypography.monoMedium),
        ],
      ),
    );
  }
}
