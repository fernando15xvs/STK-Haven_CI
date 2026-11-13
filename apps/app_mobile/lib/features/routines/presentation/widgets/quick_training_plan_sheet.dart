import 'package:core/domain/models/training_program.dart';
import 'package:core/features/programs/application/program_schedule_projector.dart';
import 'package:core/features/programs/presentation/pages/training_programs_page.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Fast path for creating a plan. All advanced options remain available in
/// TrainingProgramsPage; the user never has to configure those to start.
class QuickTrainingPlanSheet extends ConsumerStatefulWidget {
  const QuickTrainingPlanSheet({super.key, required this.scrollController});

  final ScrollController scrollController;

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.of(context).surfaceHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.42,
          maxChildSize: 0.95,
          builder: (ctx, controller) =>
              QuickTrainingPlanSheet(scrollController: controller),
        ),
      );

  @override
  ConsumerState<QuickTrainingPlanSheet> createState() => _QuickTrainingPlanSheetState();
}

class _QuickTrainingPlanSheetState extends ConsumerState<QuickTrainingPlanSheet> {
  late Set<String> _selectedRoutineIds;
  late Set<int> _weekdays;
  bool _saving = false;

  static const _dayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    final routines = ref.read(routineListProvider);
    // Do not silently include dozens of unrelated routines in a new plan.
    _selectedRoutineIds = routines.take(4).map((item) => item.id).toSet();
    _weekdays = ProgramScheduleProjector.recommendedTrainingWeekdays(
      _selectedRoutineIds.length.clamp(1, 7).toInt(),
    );
  }

  Future<void> _create() async {
    if (_saving || _selectedRoutineIds.isEmpty || _weekdays.isEmpty) return;
    setState(() => _saving = true);
    final routines = ref.read(routineListProvider);
    final orderedIds = [
      for (final routine in routines)
        if (_selectedRoutineIds.contains(routine.id)) routine.id,
    ];
    try {
      await ref.read(trainingProgramListProvider.notifier).create(
            name: 'Mi plan',
            routineIds: orderedIds,
            durationWeeks: 8,
            scheduleMode: ProgramScheduleMode.continuous,
            targetSessionsPerWeek: _weekdays.length,
            trainingWeekdays: _weekdays,
            activate: true,
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Plan creado y activado. Puedes editarlo cuando quieras.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear el plan. Revisa tus rutinas.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _advanced() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => const TrainingProgramsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final routines = ref.watch(routineListProvider);
    final colors = AppColors.of(context);
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Crear mi plan', style: AppTypography.headlineLarge),
        const SizedBox(height: 6),
        Text(
          'Selecciona tus rutinas y los días en que quieres entrenar. '
          'La app organizará una rotación automáticamente.',
          style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('1. Mis rutinas', style: AppTypography.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        for (final routine in routines)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(routine.name, style: AppTypography.bodyLarge),
            subtitle: Text('${routine.exercises.length} ejercicios'),
            value: _selectedRoutineIds.contains(routine.id),
            onChanged: _saving
                ? null
                : (checked) => setState(() {
                    if (checked == true) {
                      _selectedRoutineIds.add(routine.id);
                    } else {
                      _selectedRoutineIds.remove(routine.id);
                    }
                  }),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text('2. Días de entrenamiento', style: AppTypography.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${_weekdays.length} sesiones por semana · puedes cambiarlo después',
          style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < 7; index++)
              FilterChip(
                label: Text(_dayLabels[index]),
                selected: _weekdays.contains(index + 1),
                onSelected: _saving
                    ? null
                    : (selected) => setState(() {
                        if (selected) {
                          _weekdays.add(index + 1);
                        } else {
                          _weekdays.remove(index + 1);
                        }
                      }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          key: const Key('quick_plan_create'),
          onPressed: _saving || _selectedRoutineIds.isEmpty || _weekdays.isEmpty
              ? null
              : _create,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(_saving ? 'Creando plan…' : 'Crear y activar plan'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _saving ? null : _advanced,
          child: const Text('Configuración avanzada'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sin configurar un programa también puedes iniciar cualquier rutina.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}
