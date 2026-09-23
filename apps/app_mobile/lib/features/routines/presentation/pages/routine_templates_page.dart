import 'package:core/domain/models/routine_template.dart';
import 'package:core/features/routines/application/routine_template_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';

class RoutineTemplatesPage extends ConsumerStatefulWidget {
  const RoutineTemplatesPage({super.key});

  @override
  ConsumerState<RoutineTemplatesPage> createState() => _RoutineTemplatesPageState();
}

class _RoutineTemplatesPageState extends ConsumerState<RoutineTemplatesPage> {
  String _level = 'Todos';
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(routineTemplateServiceProvider).templates;
    final visible = _level == 'Todos'
        ? templates
        : templates.where((template) => template.level == _level).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Plantillas', style: AppTypography.displaySmall),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          PremiumCard(
            backgroundColor: AppColors.primary.withValues(alpha: 0.10),
            borderColor: AppColors.primary.withValues(alpha: 0.28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Empieza con una base', style: AppTypography.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Crea una rutina lista para personalizar. Después puedes cambiar ejercicios, días, series, superseries y notas.',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Todos', 'Principiante', 'Intermedio', 'Avanzado']
                  .map(
                    (level) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        label: Text(level),
                        selected: _level == level,
                        onSelected: (_) => setState(() => _level = level),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...visible.map(
            (template) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _TemplateCard(
                template: template,
                disabled: _creating,
                onUse: () => _useTemplate(template),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _useTemplate(RoutineTemplate template) async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final routine = await ref.read(routineTemplateServiceProvider).createFromTemplate(template);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se creó “${routine.name}”. Ya puedes personalizarla.')),
      );
      Navigator.of(context).pop(routine);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

class _TemplateCard extends StatelessWidget {
  final RoutineTemplate template;
  final bool disabled;
  final VoidCallback onUse;

  const _TemplateCard({
    required this.template,
    required this.disabled,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(template.name, style: AppTypography.headlineLarge)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  template.level,
                  style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            template.sourceProgramName,
            style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            template.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.fitness_center, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('${template.exerciseCount} ejercicios', style: AppTypography.bodySmall),
              const Spacer(),
              ...List.generate(7, (index) {
                final active = template.suggestedDays.contains(index + 1);
                return Container(
                  margin: const EdgeInsets.only(left: 3),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? AppColors.primary.withValues(alpha: 0.16) : AppColors.surfaceHigh,
                    border: Border.all(
                      color: active ? AppColors.primary.withValues(alpha: 0.45) : AppColors.surfaceBorder,
                    ),
                  ),
                  child: Text(
                    days[index],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.primary : AppColors.textDisabled,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: disabled ? null : onUse,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('USAR PLANTILLA'),
            ),
          ),
        ],
      ),
    );
  }
}
