import 'measurement_progress_panel.dart';
import '../widgets/body_measurement_silhouette.dart';
import 'package:core/features/progress/domain/measurement_progress.dart';
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
  ConsumerState<BodyMeasurementPage> createState() =>
      _BodyMeasurementPageState();
}

class _BodyMeasurementPageState extends ConsumerState<BodyMeasurementPage> {
  MeasurementMetric _selectedMeasurement = MeasurementMetric.chest;
  void _showAddMeasurementModal(
    BuildContext context, [
    BodyMeasurement? existing,
  ]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surface,
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
      body: ListView.separated(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 180,
        ),
        itemCount: measurements.length + 1,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0)
            return Column(
              children: [
                BodyMeasurementSilhouette(
                  measurements: measurements,
                  selected: _selectedMeasurement,
                  onSelected: (metric) => setState(() => _selectedMeasurement = metric),
                ),
                const SizedBox(height: AppSpacing.md),
                MeasurementProgressPanel(
                  measurements: measurements,
                  selectedMetric: _selectedMeasurement,
                ),
                if (measurements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: PrimaryButton(
                      label: 'Registrar primeras medidas',
                      onPressed: () => _showAddMeasurementModal(context),
                    ),
                  ),
              ],
            );
          final measurement = measurements[index - 1];
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
                backgroundColor: AppColors.of(context).primary,
                child: Icon(Icons.add, color: AppColors.of(context).onPrimary),
              ),
            )
          : null,
    );
  }
}

class _MeasurementCard extends ConsumerWidget {
  final BodyMeasurement measurement;
  final VoidCallback onTap;

  const _MeasurementCard({required this.measurement, required this.onTap});

  Widget _buildPill(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.of(context).primaryFaded
            : AppColors.of(context).surface,
        borderRadius: AppRadius.sm_,
        border: Border.all(
          color: highlight
              ? AppColors.of(context).primary.withValues(alpha: 0.3)
              : AppColors.of(context).surfaceBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: highlight
                  ? AppColors.of(context).primary
                  : AppColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.monoMedium.copyWith(
              color: highlight
                  ? AppColors.of(context).primary
                  : AppColors.of(context).textPrimary,
            ),
          ),
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
          color: AppColors.of(context).surfaceHigh,
          borderRadius: AppRadius.lg_,
          border: Border.all(color: AppColors.of(context).surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.straighten,
                      size: 16,
                      color: AppColors.of(context).primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat(
                        'dd MMM yyyy, HH:mm',
                        'es',
                      ).format(measurement.date),
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.of(context).primary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.of(context).error,
                    size: 20,
                  ),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('¿Eliminar este registro?'),
                        content: const Text(
                          'La evolución y el recordatorio se recalcularán con las medidas restantes.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    try {
                      final warning = await ref
                          .read(bodyMeasurementProvider.notifier)
                          .deleteMeasurement(measurement.id);
                      if (context.mounted && warning != null)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(warning)));
                    } catch (_) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo eliminar el registro.'),
                          ),
                        );
                    }
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
                  _buildPill(
                    context,
                    'Peso',
                    FitnessFormatter.formatWeight(measurement.weightKg!, unit),
                    highlight: true,
                  ),
                if (measurement.bodyFatPercentage != null)
                  _buildPill(
                    context,
                    'Grasa',
                    '${measurement.bodyFatPercentage!.toStringAsFixed(1)}%',
                  ),
                if (measurement.shouldersCm != null)
                  _buildPill(
                    context,
                    'Hombros',
                    '${measurement.shouldersCm!.toStringAsFixed(1)} cm',
                  ),
                if (measurement.chestCm != null)
                  _buildPill(
                    context,
                    'Pecho',
                    '${measurement.chestCm!.toStringAsFixed(1)} cm',
                  ),
                if (measurement.waistCm != null)
                  _buildPill(
                    context,
                    'Cintura',
                    '${measurement.waistCm!.toStringAsFixed(1)} cm',
                  ),
                if (measurement.hipsCm != null)
                  _buildPill(
                    context,
                    'Caderas',
                    '${measurement.hipsCm!.toStringAsFixed(1)} cm',
                  ),
                if (measurement.leftArmCm != null ||
                    measurement.rightArmCm != null)
                  _buildPill(
                    context,
                    'Brazos (I/D)',
                    '${measurement.leftArmCm?.toStringAsFixed(1) ?? '-'} / ${measurement.rightArmCm?.toStringAsFixed(1) ?? '-'} cm',
                  ),
                if (measurement.leftLegCm != null ||
                    measurement.rightLegCm != null)
                  _buildPill(
                    context,
                    'Piernas (I/D)',
                    '${measurement.leftLegCm?.toStringAsFixed(1) ?? '-'} / ${measurement.rightLegCm?.toStringAsFixed(1) ?? '-'} cm',
                  ),
                if (measurement.calvesCm != null)
                  _buildPill(
                    context,
                    'Gemelos',
                    '${measurement.calvesCm!.toStringAsFixed(1)} cm',
                  ),
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
  ConsumerState<_AddMeasurementModal> createState() =>
      _AddMeasurementModalState();
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

    _weightCtrl = TextEditingController(
      text: displayWeight != null ? _fmt(displayWeight) : '',
    );
    _fatCtrl = TextEditingController(
      text: m?.bodyFatPercentage != null ? _fmt(m!.bodyFatPercentage!) : '',
    );
    _shouldersCtrl = TextEditingController(
      text: m?.shouldersCm != null ? _fmt(m!.shouldersCm!) : '',
    );
    _chestCtrl = TextEditingController(
      text: m?.chestCm != null ? _fmt(m!.chestCm!) : '',
    );
    _waistCtrl = TextEditingController(
      text: m?.waistCm != null ? _fmt(m!.waistCm!) : '',
    );
    _hipsCtrl = TextEditingController(
      text: m?.hipsCm != null ? _fmt(m!.hipsCm!) : '',
    );
    _leftArmCtrl = TextEditingController(
      text: m?.leftArmCm != null ? _fmt(m!.leftArmCm!) : '',
    );
    _rightArmCtrl = TextEditingController(
      text: m?.rightArmCm != null ? _fmt(m!.rightArmCm!) : '',
    );
    _leftLegCtrl = TextEditingController(
      text: m?.leftLegCm != null ? _fmt(m!.leftLegCm!) : '',
    );
    _rightLegCtrl = TextEditingController(
      text: m?.rightLegCm != null ? _fmt(m!.rightLegCm!) : '',
    );
    _calvesCtrl = TextEditingController(
      text: m?.calvesCm != null ? _fmt(m!.calvesCm!) : '',
    );
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

  bool _saving = false;
  double? _parse(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final controllers = [
      _weightCtrl,
      _fatCtrl,
      _shouldersCtrl,
      _chestCtrl,
      _waistCtrl,
      _hipsCtrl,
      _leftArmCtrl,
      _rightArmCtrl,
      _leftLegCtrl,
      _rightLegCtrl,
      _calvesCtrl,
    ];
    if (controllers.every((c) => c.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce al menos una medida.')),
      );
      return;
    }
    final unit = ref.read(settingsProvider).weightUnit;
    final displayWeight = _parse(_weightCtrl.text);
    final canonicalWeight = displayWeight != null
        ? WeightConverter.toCanonicalKg(displayWeight, unit)
        : null;

    final newMeasurement = BodyMeasurement(
      id: widget.existingMeasurement?.id ?? const Uuid().v4(),
      date: widget.existingMeasurement?.date ?? DateTime.now(),
      weightKg: canonicalWeight,
      bodyFatPercentage: _parse(_fatCtrl.text),
      shouldersCm: _parse(_shouldersCtrl.text),
      chestCm: _parse(_chestCtrl.text),
      waistCm: _parse(_waistCtrl.text),
      hipsCm: _parse(_hipsCtrl.text),
      leftArmCm: _parse(_leftArmCtrl.text),
      rightArmCm: _parse(_rightArmCtrl.text),
      leftLegCm: _parse(_leftLegCtrl.text),
      rightLegCm: _parse(_rightLegCtrl.text),
      calvesCm: _parse(_calvesCtrl.text),
    );

    setState(() => _saving = true);
    try {
      final warning = await ref
          .read(bodyMeasurementProvider.notifier)
          .saveMeasurement(newMeasurement);
      if (!mounted) return;
      if (warning != null)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(warning)));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar. Inténtalo de nuevo.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController controller,
    String suffix,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        validator: (text) {
          if (text == null || text.trim().isEmpty) return null;
          final value = _parse(text);
          if (value == null || !value.isFinite || value <= 0)
            return 'Introduce un número mayor que cero';
          if (suffix == '%' && value > 100)
            return 'El porcentaje no puede superar 100';
          return null;
        },
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppTypography.monoMedium.copyWith(
          color: AppColors.of(context).textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTypography.bodyMedium.copyWith(
            color: AppColors.of(context).textSecondary,
          ),
          suffixText: suffix,
          suffixStyle: AppTypography.monoMedium.copyWith(
            color: AppColors.of(context).textSecondary,
          ),
          filled: true,
          fillColor: AppColors.of(context).surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.of(context).surfaceBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.of(context).surfaceBorder),
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
                        color: AppColors.of(context).surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    widget.existingMeasurement == null
                        ? 'Nueva Medida'
                        : 'Editar Medida',
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.of(context).textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  _buildField(context, 'Peso', _weightCtrl, unit.label),
                  _buildField(context, 'Grasa Corporal', _fatCtrl, '%'),

                  Divider(
                    height: 32,
                    color: AppColors.of(context).surfaceBorder,
                  ),
                  Text(
                    'Medidas (cm)',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.of(context).primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  _buildField(context, 'Hombros', _shouldersCtrl, 'cm'),
                  _buildField(context, 'Pecho', _chestCtrl, 'cm'),
                  _buildField(context, 'Cintura', _waistCtrl, 'cm'),
                  _buildField(context, 'Caderas o Glúteos', _hipsCtrl, 'cm'),

                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          context,
                          'Brazo Izq',
                          _leftArmCtrl,
                          'cm',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildField(
                          context,
                          'Brazo Der',
                          _rightArmCtrl,
                          'cm',
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          context,
                          'Pierna Izq',
                          _leftLegCtrl,
                          'cm',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildField(
                          context,
                          'Pierna Der',
                          _rightLegCtrl,
                          'cm',
                        ),
                      ),
                    ],
                  ),

                  _buildField(context, 'Gemelos', _calvesCtrl, 'cm'),

                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: _saving ? 'Guardando…' : 'Guardar',
                    onPressed: () {
                      if (!_saving) _save();
                    },
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
