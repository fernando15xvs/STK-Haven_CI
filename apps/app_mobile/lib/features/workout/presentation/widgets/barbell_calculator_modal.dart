import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/primary_button.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/workout/application/barbell_calculator.dart';

class BarbellCalculatorModal extends ConsumerStatefulWidget {
  final double? initialTargetWeight;

  const BarbellCalculatorModal({super.key, this.initialTargetWeight});

  static Future<void> show(BuildContext context, {double? initialTargetWeight}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BarbellCalculatorModal(initialTargetWeight: initialTargetWeight),
      ),
    );
  }

  @override
  ConsumerState<BarbellCalculatorModal> createState() => _BarbellCalculatorModalState();
}

class _BarbellCalculatorModalState extends ConsumerState<BarbellCalculatorModal> {
  late TextEditingController _weightCtrl;
  BarbellCalculatorResult? _result;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTargetWeight ?? 0;
    _weightCtrl = TextEditingController(text: initial > 0 ? initial.toString() : '');
    if (initial > 0) {
      // Delay to let provider read settings
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculate());
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final weight = double.tryParse(_weightCtrl.text) ?? 0;
    if (weight <= 0) {
      setState(() => _result = null);
      return;
    }

    final unit = ref.read(settingsProvider).weightUnit;
    final isLb = unit == WeightUnit.lb;

    final barWeight = isLb ? 45.0 : 20.0;
    final plates = isLb 
      ? const [45.0, 35.0, 25.0, 10.0, 5.0, 2.5]
      : const [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

    setState(() {
      _result = BarbellCalculator.calculate(
        targetWeight: weight,
        barWeight: barWeight,
        availablePlates: plates,
      );
    });
  }

  Color _getPlateColor(double weight, bool isLb) {
    if (isLb) {
      if (weight >= 45) return Colors.red;
      if (weight >= 35) return Colors.blue;
      if (weight >= 25) return Colors.green;
      if (weight >= 10) return Colors.white;
      return AppColors.textSecondary;
    } else {
      if (weight >= 25) return Colors.red;
      if (weight >= 20) return Colors.blue;
      if (weight >= 15) return Colors.yellow;
      if (weight >= 10) return Colors.green;
      if (weight >= 5) return Colors.white;
      return AppColors.textSecondary;
    }
  }

  double _getPlateHeight(double weight, bool isLb) {
    final maxWeight = isLb ? 45.0 : 25.0;
    final ratio = weight / maxWeight;
    return 60.0 + (ratio * 40.0); // 60 to 100 height
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(settingsProvider).weightUnit;
    final isLb = unit == WeightUnit.lb;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Calculadora de Discos', style: AppTypography.headlineMedium.copyWith(color: AppColors.primary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.headlineLarge,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Peso total esperado (${unit.label})',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _calculate(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_result != null) ...[
            Text('Barra: ${_result!.barWeight} ${unit.label}', style: AppTypography.bodyMedium),
            const SizedBox(height: 16),
            if (_result!.platesPerSide.isEmpty)
              Text('Usa solo la barra vacía', style: AppTypography.headlineSmall.copyWith(color: AppColors.textSecondary))
            else
              _buildVisualizer(_result!, isLb),
            
            const SizedBox(height: 16),
            if (_result!.remainder > 0)
              Text('Sobran ${_result!.remainder.toStringAsFixed(1)} ${unit.label}', style: AppTypography.bodySmall.copyWith(color: AppColors.warning)),
          ],

          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Cerrar',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizer(BarbellCalculatorResult result, bool isLb) {
    return Container(
      height: 120,
      width: double.infinity,
      color: AppColors.surface,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Barra
              Container(
                width: 100,
                height: 12,
                color: Colors.grey.shade400,
              ),
              // Manga de la barra
              Container(
                width: 10,
                height: 30,
                color: Colors.grey.shade300,
              ),
              const SizedBox(width: 2),
              // Discos
              ...result.platesPerSide.map((plate) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    width: 20,
                    height: _getPlateHeight(plate.weight, isLb),
                    decoration: BoxDecoration(
                      color: _getPlateColor(plate.weight, isLb),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black54),
                    ),
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          plate.weight % 1 == 0 ? plate.weight.toInt().toString() : plate.weight.toString(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: plate.weight >= 10 && plate.weight != 15 ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 2),
              // Manga sobrante
              Container(
                width: 40,
                height: 12,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
