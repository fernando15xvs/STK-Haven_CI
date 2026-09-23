import 'package:core/domain/models/routine_template.dart';
import 'package:core/features/routines/application/routine_template_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';

class RoutineTemplatesPageWeb extends ConsumerStatefulWidget {
  const RoutineTemplatesPageWeb({super.key});

  @override
  ConsumerState<RoutineTemplatesPageWeb> createState() => _RoutineTemplatesPageWebState();
}

class _RoutineTemplatesPageWebState extends ConsumerState<RoutineTemplatesPageWeb> {
  String _level = 'Todos';
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(routineTemplateServiceProvider).templates;
    final visible = _level == 'Todos'
        ? templates
        : templates.where((template) => template.level == _level).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Plantillas de rutina'),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: AppRadius.lg_,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.auto_awesome_outlined, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Empieza con una base', style: AppTypography.headlineLarge),
                                const SizedBox(height: 4),
                                Text(
                                  'Elige una rutina preconfigurada y después personalízala: ejercicios, días, series, superseries y notas.',
                                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Todos', 'Principiante', 'Intermedio', 'Avanzado']
                          .map(
                            (level) => ChoiceChip(
                              label: Text(level),
                              selected: _level == level,
                              onSelected: (_) => setState(() => _level = level),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 70),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      final columns = width >= 940 ? 3 : width >= 620 ? 2 : 1;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: columns == 1 ? 1.9 : 1.35,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _TemplateCard(
                            template: visible[index],
                            disabled: _creating,
                            onUse: () => _useTemplate(visible[index]),
                          ),
                          childCount: visible.length,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
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
    const dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineLarge,
                ),
              ),
              const SizedBox(width: 8),
              Chip(label: Text(template.level), visualDensity: VisualDensity.compact),
            ],
          ),
          Text(
            template.sourceProgramName,
            style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              template.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.45),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.fitness_center, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('${template.exerciseCount} ejercicios', style: AppTypography.bodySmall),
              const Spacer(),
              ...List.generate(7, (index) {
                final active = template.suggestedDays.contains(index + 1);
                return Container(
                  margin: const EdgeInsets.only(left: 3),
                  width: 23,
                  height: 23,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? AppColors.primary.withValues(alpha: 0.16) : AppColors.surfaceHigh,
                    border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.45) : AppColors.border),
                  ),
                  child: Text(
                    dayLabels[index],
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: disabled ? null : onUse,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Usar plantilla'),
            ),
          ),
        ],
      ),
    );
  }
}
