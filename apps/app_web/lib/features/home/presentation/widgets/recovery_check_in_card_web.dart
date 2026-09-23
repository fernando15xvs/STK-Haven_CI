import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/recovery/application/recovery_history.dart';
import 'package:core/features/recovery/application/recovery_performance_correlation.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';

import '../../../../core/theme/app_colors.dart';
import 'recovery_history_dialog_web.dart';

class RecoveryCheckInCardWeb extends ConsumerWidget {
  const RecoveryCheckInCardWeb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkIn = ref.watch(recoveryProvider);
    final history = ref.watch(recoveryHistoryProvider);
    final snapshot = RecoveryHistorySnapshot.fromEntries(history);
    final performance = ref.watch(recoveryPerformanceProvider);
    final color = _statusColor(checkIn);
    final onHistory = history.isEmpty
        ? null
        : () {
            showRecoveryHistoryDialogWeb(context, history, performance);
          };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDialog(context, ref, checkIn),
        borderRadius: AppRadius.lg_,
        child: AnimatedContainer(
          duration: AppMotion.standard,
          curve: AppMotion.curve,
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lg_,
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: AppElevation.soft,
          ),
          child: checkIn == null
              ? _EmptyRecoveryState(onHistory: onHistory)
              : _RecoverySummary(
                  checkIn: checkIn,
                  history: snapshot,
                  onHistory: onHistory,
                ),
        ),
      ),
    );
  }

  Future<void> _showDialog(
    BuildContext context,
    WidgetRef ref,
    RecoveryCheckIn? current,
  ) async {
    var energy = current?.energy ?? 3;
    var sleep = current?.sleep ?? 3;
    var stress = current?.stress ?? 3;
    var soreness = current?.soreness ?? 3;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceHigh,
              title: const Text('Check-in de recuperación'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evalúa rápidamente cómo llegas hoy. STK Haven usa estas respuestas solo para ajustar la recomendación del día.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _RatingRow(
                        icon: Icons.bolt_outlined,
                        label: 'Energía',
                        hint: '1 = muy baja · 5 = excelente',
                        value: energy,
                        onChanged: (value) =>
                            setDialogState(() => energy = value),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _RatingRow(
                        icon: Icons.bedtime_outlined,
                        label: 'Sueño',
                        hint: '1 = dormí mal · 5 = muy reparador',
                        value: sleep,
                        onChanged: (value) =>
                            setDialogState(() => sleep = value),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _RatingRow(
                        icon: Icons.psychology_alt_outlined,
                        label: 'Estrés',
                        hint: '1 = bajo · 5 = muy alto',
                        value: stress,
                        onChanged: (value) =>
                            setDialogState(() => stress = value),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _RatingRow(
                        icon: Icons.accessibility_new_outlined,
                        label: 'Molestia muscular',
                        hint: '1 = mínima · 5 = muy marcada',
                        value: soreness,
                        onChanged: (value) =>
                            setDialogState(() => soreness = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    await ref.read(recoveryProvider.notifier).save(
                          energy: energy,
                          sleep: sleep,
                          stress: stress,
                          soreness: soreness,
                        );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  icon: const Icon(Icons.check),
                  label: Text(current == null ? 'Guardar' : 'Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Color _statusColor(RecoveryCheckIn? checkIn) {
    if (checkIn == null) return AppColors.primary;
    return switch (checkIn.status) {
      RecoveryStatus.ready => AppColors.success,
      RecoveryStatus.moderate => AppColors.warning,
      RecoveryStatus.low => AppColors.error,
    };
  }
}

class _EmptyRecoveryState extends StatelessWidget {
  final VoidCallback? onHistory;

  const _EmptyRecoveryState({this.onHistory});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primaryFaded,
            borderRadius: AppRadius.md_,
          ),
          child: const Icon(Icons.favorite_outline, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Cómo llega tu cuerpo hoy?',
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: 3),
              Text(
                'Energía, sueño, estrés y molestias en un check-in rápido.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (onHistory != null)
          IconButton(
            tooltip: 'Ver historial de recuperación',
            onPressed: onHistory,
            icon: const Icon(
              Icons.insights_outlined,
              color: AppColors.primary,
            ),
          )
        else
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ],
    );
  }
}

class _RecoverySummary extends StatelessWidget {
  final RecoveryCheckIn checkIn;
  final RecoveryHistorySnapshot history;
  final VoidCallback? onHistory;

  const _RecoverySummary({
    required this.checkIn,
    required this.history,
    this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (checkIn.status) {
      RecoveryStatus.ready => AppColors.success,
      RecoveryStatus.moderate => AppColors.warning,
      RecoveryStatus.low => AppColors.error,
    };
    final trends = <(String, RecoveryMetricTrend?)>[
      ('Energía', history.energyTrend),
      ('Sueño', history.sleepTrend),
      ('Estrés', history.stressTrend),
      ('Molestia', history.sorenessTrend),
    ].where((item) => item.$2 != null).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: checkIn.score / 100,
                strokeWidth: 5,
                backgroundColor: AppColors.surfaceBorder,
                color: color,
              ),
              Text(
                '${checkIn.score}',
                style: AppTypography.labelLarge.copyWith(color: color),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RECUPERACIÓN DE HOY',
                style: AppTypography.labelMedium.copyWith(color: color),
              ),
              const SizedBox(height: 3),
              Text(checkIn.status.label, style: AppTypography.headlineMedium),
              const SizedBox(height: 7),
              Text(
                checkIn.recommendation,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              if (trends.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: trends
                      .map(
                        (item) => _TrendChip(
                          label: item.$1,
                          trend: item.$2!,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
        if (onHistory != null)
          IconButton(
            tooltip: 'Ver historial de recuperación',
            onPressed: onHistory,
            icon: const Icon(
              Icons.insights_outlined,
              color: AppColors.primary,
            ),
          )
        else
          const Icon(Icons.tune, color: AppColors.textSecondary),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.label, required this.trend});

  final String label;
  final RecoveryMetricTrend trend;

  @override
  Widget build(BuildContext context) {
    final symbol = trend.isStable
        ? '→'
        : trend.delta > 0
            ? '↑'
            : '↓';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.sm_,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Text(
        '$label $symbol ${trend.recentAverage.toStringAsFixed(1)}/5',
        style: AppTypography.labelSmall,
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final int value;
  final ValueChanged<int> onChanged;

  const _RatingRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: AppTypography.headlineSmall),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                hint,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: List.generate(5, (index) {
            final rating = index + 1;
            final selected = rating == value;
            return ChoiceChip(
              label: Text('$rating'),
              selected: selected,
              onSelected: (_) => onChanged(rating),
            );
          }),
        ),
      ],
    );
  }
}
