import '../widgets/body_measurement_silhouette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/components/primary_button.dart';
import 'package:core/core/utils/weight_converter.dart';
import 'package:core/domain/models/body_measurement.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/core/utils/fitness_formatter.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';
import 'package:core/features/progress/domain/measurement_progress.dart';
import 'package:core/features/progress/presentation/widgets/measurement_reminder_controls.dart';

class BodyMeasurementPage extends ConsumerStatefulWidget {
  const BodyMeasurementPage({super.key});

  @override
  ConsumerState<BodyMeasurementPage> createState() =>
      _BodyMeasurementPageState();
}

class _BodyMeasurementPageState extends ConsumerState<BodyMeasurementPage> {
  MeasurementMetric _selectedMeasurement = MeasurementMetric.chest;

  Future<void> _showAddMeasurementModal(BuildContext context,
      [BodyMeasurement? existing]) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        final keyboard = MediaQuery.viewInsetsOf(sheetContext).bottom;
        final available = MediaQuery.sizeOf(sheetContext).height - keyboard;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: SizedBox(
            height: available * .90,
            child: _AddMeasurementModal(existingMeasurement: existing),
          ),
        );
      },
    );
  }

  Future<void> _showHistory(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .70,
        minChildSize: .35,
        maxChildSize: .95,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, _) {
            final records = ref.watch(bodyMeasurementProvider);
            final weightUnit = ref.watch(settingsProvider).weightUnit;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(child: Text('Historial de registros',
                    style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    key: const Key('measurement_history_close'),
                    tooltip: 'Cerrar historial',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ]),
              ),
              Expanded(child: records.isEmpty
                ? const Center(child: Text('Todavía no hay medidas registradas.'))
                : ListView.separated(
                  controller: scrollController,
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return ListTile(
                      key: ValueKey('measurement_record_${record.id}'),
                      leading: Icon(Icons.straighten,
                        color: AppColors.of(context).primary),
                      title: Text(DateFormat('dd MMM yyyy, HH:mm', 'es')
                        .format(record.date)),
                      subtitle: Text([
                        if (record.weightKg != null)
                          'Peso: ${FitnessFormatter.formatWeight(record.weightKg!, weightUnit)}',
                        if (record.chestCm != null)
                          'Pecho: ${record.chestCm!.toStringAsFixed(1)} cm',
                        if (record.waistCm != null)
                          'Cintura: ${record.waistCm!.toStringAsFixed(1)} cm',
                      ].join(' · ').isEmpty
                        ? 'Medidas corporales registradas'
                        : [
                          if (record.weightKg != null)
                            'Peso: ${FitnessFormatter.formatWeight(record.weightKg!, weightUnit)}',
                          if (record.chestCm != null)
                            'Pecho: ${record.chestCm!.toStringAsFixed(1)} cm',
                          if (record.waistCm != null)
                            'Cintura: ${record.waistCm!.toStringAsFixed(1)} cm',
                        ].join(' · ')),
                      trailing: Row(mainAxisSize: MainAxisSize.min,children: [
                        IconButton(
                          tooltip: 'Editar registro',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _showAddMeasurementModal(this.context, record);
                          },
                        ),
                        IconButton(
                          tooltip: 'Eliminar registro',
                          icon: Icon(Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('¿Eliminar este registro?'),
                                content: const Text(
                                  'Esta acción eliminará solo el registro '
                                  'seleccionado y actualizará las medidas visibles.'),
                                actions: [
                                  TextButton(onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                    child: const Text('Cancelar')),
                                  TextButton(onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                    child: const Text('Eliminar')),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            try {
                              final warning = await ref
                                .read(bodyMeasurementProvider.notifier)
                                .deleteMeasurement(record.id);
                              if (context.mounted && warning != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(warning)));
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content:
                                    Text('No se pudo eliminar el registro.')));
                              }
                            }
                          },
                        ),
                      ]),
                    );
                  },
                )),
            ]);
          },
        ),
      ),
    );

  @override
  Widget build(BuildContext context) {
    final measurements = ref.watch(bodyMeasurementProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        key: const Key('body_measurement_main_list'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('measurement_history_button'),
                onPressed: measurements.isEmpty ? null
                    : () => _showHistory(context),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Historial'),
              ),
              FilledButton.icon(
                key: const Key('measurement_add_button'),
                onPressed: () => _showAddMeasurementModal(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva medida'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          BodyMeasurementSilhouette(
            measurements: measurements,
            selected: _selectedMeasurement,
            onSelected: (metric) =>
              setState(() => _selectedMeasurement = metric),
          ),
        ],
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

    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(children: [
            // A persistent close action: long forms must never trap users.
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 8, 6),
              child: Row(children: [
                Expanded(child: Text(
                  widget.existingMeasurement == null
                    ? 'Nueva medida' : 'Editar medida',
                  style: AppTypography.headlineMedium.copyWith(
                    color: AppColors.of(context).textPrimary),
                )),
                IconButton(
                  key: const Key('measurement_modal_close'),
                  tooltip: 'Cerrar sin guardar',
                  icon: const Icon(Icons.close),
                  onPressed: _saving ? null
                    : () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            Divider(height: 1,color:AppColors.of(context).surfaceBorder),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('measurement_modal_scroll'),
                keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Registra únicamente las medidas que tomaste.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.of(context).textSecondary)),
                    const SizedBox(height: AppSpacing.md),
                    _buildField(context,'Peso',_weightCtrl,unit.label),
                    _buildField(context,'Grasa corporal',_fatCtrl,'%'),
                    Divider(height:32,
                      color:AppColors.of(context).surfaceBorder),
                    Text('Perímetros (cm)',
                      style:AppTypography.labelLarge.copyWith(
                        color:AppColors.of(context).primary)),
                    const SizedBox(height: AppSpacing.md),
                    _buildField(context,'Hombros',_shouldersCtrl,'cm'),
                    _buildField(context,'Pecho',_chestCtrl,'cm'),
                    _buildField(context,'Cintura',_waistCtrl,'cm'),
                    _buildField(context,'Caderas o glúteos',_hipsCtrl,'cm'),
                    Row(children:[
                      Expanded(child:_buildField(
                        context,'Brazo izq.',_leftArmCtrl,'cm')),
                      const SizedBox(width:AppSpacing.md),
                      Expanded(child:_buildField(
                        context,'Brazo der.',_rightArmCtrl,'cm')),
                    ]),
                    Row(children:[
                      Expanded(child:_buildField(
                        context,'Pierna izq.',_leftLegCtrl,'cm')),
                      const SizedBox(width:AppSpacing.md),
                      Expanded(child:_buildField(
                        context,'Pierna der.',_rightLegCtrl,'cm')),
                    ]),
                    _buildField(context,'Gemelos',_calvesCtrl,'cm'),
                    Divider(height:32,
                      color:AppColors.of(context).surfaceBorder),
                    MeasurementReminderControls(
                      compact:true,
                      measurements:ref.watch(bodyMeasurementProvider),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height:1,color:AppColors.of(context).surfaceBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children:[
                OutlinedButton(
                  key: const Key('measurement_modal_cancel'),
                  onPressed: _saving ? null
                    : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width:12),
                Expanded(child: PrimaryButton(
                  label:_saving?'Guardando…':'Guardar medida',
                  onPressed: () { if (!_saving) _save(); },
                )),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
