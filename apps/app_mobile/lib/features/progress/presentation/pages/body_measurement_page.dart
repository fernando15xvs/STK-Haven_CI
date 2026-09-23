import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/components/primary_button.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';

class BodyMeasurementPage extends ConsumerStatefulWidget {
  const BodyMeasurementPage({super.key});

  @override
  ConsumerState<BodyMeasurementPage> createState() => _BodyMeasurementPageState();
}

class _BodyMeasurementPageState extends ConsumerState<BodyMeasurementPage> {
  void _showAddMeasurementModal(BuildContext context, [BodyMeasurement? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => _AddMeasurementModal(existingMeasurement: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final measurements = ref.watch(bodyMeasurementProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: measurements.isEmpty
          ? Center(
              child: Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.accessibility_new, size: 64, color: AppColors.textSecondary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No hay medidas registradas',
                      style: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Registra tu peso y medidas corporales para ver tu evolución en el tiempo.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'Registrar Medida',
                      onPressed: () => _showAddMeasurementModal(context),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              itemCount: measurements.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final measurement = measurements[index];
                return _MeasurementCard(
                  measurement: measurement,
                  onTap: () => _showAddMeasurementModal(context, measurement),
                );
              },
            ),
      floatingActionButton: measurements.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: FloatingActionButton(
                onPressed: () => _showAddMeasurementModal(context),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            )
          : null,
    );
  }
}

class _MeasurementCard extends ConsumerWidget {
  final BodyMeasurement measurement;
  final VoidCallback onTap;

  const _MeasurementCard({
    required this.measurement,
    required this.onTap,
  });

  Widget _buildPill(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primaryFaded : AppColors.surface,
        borderRadius: AppRadius.sm_,
        border: Border.all(color: highlight ? AppColors.primary.withValues(alpha: 0.3) : AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelSmall.copyWith(color: highlight ? AppColors.primary : AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: AppTypography.monoMedium.copyWith(color: highlight ? AppColors.primary : AppColors.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final unit = settings.weightUnit;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: AppRadius.lg_,
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.straighten, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm', 'es').format(measurement.date),
                      style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  onPressed: () {
                    ref.read(bodyMeasurementProvider.notifier).deleteMeasurement(measurement.id);
                  },
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (measurement.weightKg != null)
                  _buildPill('Peso', FitnessFormatter.formatWeight(measurement.weightKg!, unit), highlight: true),
                if (measurement.bodyFatPercentage != null)
                  _buildPill('Grasa', '${measurement.bodyFatPercentage!.toStringAsFixed(1)}%'),
                if (measurement.shouldersCm != null)
                  _buildPill('Hombros', '${measurement.shouldersCm!.toStringAsFixed(1)} cm'),
                if (measurement.chestCm != null)
                  _buildPill('Pecho', '${measurement.chestCm!.toStringAsFixed(1)} cm'),
                if (measurement.waistCm != null)
                  _buildPill('Cintura', '${measurement.waistCm!.toStringAsFixed(1)} cm'),
                if (measurement.hipsCm != null)
                  _buildPill('Caderas', '${measurement.hipsCm!.toStringAsFixed(1)} cm'),
                if (measurement.leftArmCm != null || measurement.rightArmCm != null)
                  _buildPill('Brazos (I/D)', '${measurement.leftArmCm?.toStringAsFixed(1) ?? '-'} / ${measurement.rightArmCm?.toStringAsFixed(1) ?? '-'} cm'),
                if (measurement.leftLegCm != null || measurement.rightLegCm != null)
                  _buildPill('Piernas (I/D)', '${measurement.leftLegCm?.toStringAsFixed(1) ?? '-'} / ${measurement.rightLegCm?.toStringAsFixed(1) ?? '-'} cm'),
                if (measurement.calvesCm != null)
                  _buildPill('Gemelos', '${measurement.calvesCm!.toStringAsFixed(1)} cm'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMeasurementModal extends ConsumerStatefulWidget {
  final BodyMeasurement? existingMeasurement;

  const _AddMeasurementModal({this.existingMeasurement});

  @override
  ConsumerState<_AddMeasurementModal> createState() => _AddMeasurementModalState();
}

class _AddMeasurementModalState extends ConsumerState<_AddMeasurementModal> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _weightCtrl;
  late TextEditingController _fatCtrl;
  late TextEditingController _shouldersCtrl;
  late TextEditingController _chestCtrl;
  late TextEditingController _waistCtrl;
  late TextEditingController _hipsCtrl;
  late TextEditingController _leftArmCtrl;
  late TextEditingController _rightArmCtrl;
  late TextEditingController _leftLegCtrl;
  late TextEditingController _rightLegCtrl;
  late TextEditingController _calvesCtrl;

  @override
  void initState() {
    super.initState();
    final m = widget.existingMeasurement;
    
    // Convert weight to display unit
    final unit = ref.read(settingsProvider).weightUnit;
    final displayWeight = m?.weightKg != null 
        ? WeightConverter.displayWeight(m!.weightKg!, unit) 
        : null;

    _weightCtrl = TextEditingController(text: displayWeight != null ? _fmt(displayWeight) : '');
    _fatCtrl = TextEditingController(text: m?.bodyFatPercentage != null ? _fmt(m!.bodyFatPercentage!) : '');
    _shouldersCtrl = TextEditingController(text: m?.shouldersCm != null ? _fmt(m!.shouldersCm!) : '');
    _chestCtrl = TextEditingController(text: m?.chestCm != null ? _fmt(m!.chestCm!) : '');
    _waistCtrl = TextEditingController(text: m?.waistCm != null ? _fmt(m!.waistCm!) : '');
    _hipsCtrl = TextEditingController(text: m?.hipsCm != null ? _fmt(m!.hipsCm!) : '');
    _leftArmCtrl = TextEditingController(text: m?.leftArmCm != null ? _fmt(m!.leftArmCm!) : '');
    _rightArmCtrl = TextEditingController(text: m?.rightArmCm != null ? _fmt(m!.rightArmCm!) : '');
    _leftLegCtrl = TextEditingController(text: m?.leftLegCm != null ? _fmt(m!.leftLegCm!) : '');
    _rightLegCtrl = TextEditingController(text: m?.rightLegCm != null ? _fmt(m!.rightLegCm!) : '');
    _calvesCtrl = TextEditingController(text: m?.calvesCm != null ? _fmt(m!.calvesCm!) : '');
  }

  String _fmt(double v) => v % 1 == 0 ? '${v.toInt()}' : '$v';

  @override
  void dispose() {
    _weightCtrl.dispose();
    _fatCtrl.dispose();
    _shouldersCtrl.dispose();
    _chestCtrl.dispose();
    _waistCtrl.dispose();
    _hipsCtrl.dispose();
    _leftArmCtrl.dispose();
    _rightArmCtrl.dispose();
    _leftLegCtrl.dispose();
    _rightLegCtrl.dispose();
    _calvesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final unit = ref.read(settingsProvider).weightUnit;
    
    final displayWeight = double.tryParse(_weightCtrl.text);
    final canonicalWeight = displayWeight != null 
        ? WeightConverter.toCanonicalKg(displayWeight, unit) 
        : null;

    final newMeasurement = BodyMeasurement(
      id: widget.existingMeasurement?.id ?? const Uuid().v4(),
      date: widget.existingMeasurement?.date ?? DateTime.now(),
      weightKg: canonicalWeight,
      bodyFatPercentage: double.tryParse(_fatCtrl.text),
      shouldersCm: double.tryParse(_shouldersCtrl.text),
      chestCm: double.tryParse(_chestCtrl.text),
      waistCm: double.tryParse(_waistCtrl.text),
      hipsCm: double.tryParse(_hipsCtrl.text),
      leftArmCm: double.tryParse(_leftArmCtrl.text),
      rightArmCm: double.tryParse(_rightArmCtrl.text),
      leftLegCm: double.tryParse(_leftLegCtrl.text),
      rightLegCm: double.tryParse(_rightLegCtrl.text),
      calvesCm: double.tryParse(_calvesCtrl.text),
    );

    ref.read(bodyMeasurementProvider.notifier).saveMeasurement(newMeasurement);
    Navigator.of(context).pop();
  }

  Widget _buildField(String label, TextEditingController controller, String suffix) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppTypography.monoMedium.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          suffixText: suffix,
          suffixStyle: AppTypography.monoMedium.copyWith(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.surfaceBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.surfaceBorder),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(settingsProvider).weightUnit;
    final insets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    widget.existingMeasurement == null ? 'Nueva Medida' : 'Editar Medida',
                    style: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  _buildField('Peso', _weightCtrl, unit.label),
                  _buildField('Grasa Corporal', _fatCtrl, '%'),
                  
                  const Divider(height: 32, color: AppColors.surfaceBorder),
                  Text('Medidas (cm)', style: AppTypography.labelLarge.copyWith(color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.md),
                  
                  _buildField('Hombros', _shouldersCtrl, 'cm'),
                  _buildField('Pecho', _chestCtrl, 'cm'),
                  _buildField('Cintura', _waistCtrl, 'cm'),
                  _buildField('Caderas o Glúteos', _hipsCtrl, 'cm'),
                  
                  Row(
                    children: [
                      Expanded(child: _buildField('Brazo Izq', _leftArmCtrl, 'cm')),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _buildField('Brazo Der', _rightArmCtrl, 'cm')),
                    ],
                  ),
                  
                  Row(
                    children: [
                      Expanded(child: _buildField('Pierna Izq', _leftLegCtrl, 'cm')),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _buildField('Pierna Der', _rightLegCtrl, 'cm')),
                    ],
                  ),
                  
                  _buildField('Gemelos', _calvesCtrl, 'cm'),

                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Guardar',
                    onPressed: _save,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
