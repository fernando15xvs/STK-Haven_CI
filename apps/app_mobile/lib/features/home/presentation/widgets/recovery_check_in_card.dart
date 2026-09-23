import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/recovery/application/recovery_history.dart';
import 'package:core/features/recovery/application/recovery_performance_correlation.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';

import 'recovery_history_sheet.dart';

class RecoveryCheckInCard extends ConsumerWidget {
  const RecoveryCheckInCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkIn = ref.watch(recoveryProvider);
    final history = ref.watch(recoveryHistoryProvider);
    final snapshot = RecoveryHistorySnapshot.fromEntries(history);
    final performance = ref.watch(recoveryPerformanceProvider);
    final onHistory = history.isEmpty
        ? null
        : () {
            showRecoveryHistorySheet(context, history, performance);
          };

    return PremiumCard(
      onTap: () => _showCheckInSheet(context, ref, checkIn),
      borderColor: _statusColor(checkIn).withValues(alpha: 0.32),
      child: checkIn == null
          ? _EmptyRecoveryState(onHistory: onHistory)
          : _RecoverySummary(
              checkIn: checkIn,
              history: snapshot,
              onHistory: onHistory,
            ),
    );
  }

  Future<void> _showCheckInSheet(
    BuildContext context,
    WidgetRef ref,
    RecoveryCheckIn? current,
  ) async {
    var energy = current?.energy ?? 3;
    var sleep = current?.sleep ?? 3;
    var stress = current?.stress ?? 3;
    var soreness = current?.soreness ?? 3;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textDisabled,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Check-in de recuperación',
                    style: AppTypography.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Cuatro respuestas rápidas para ajustar mejor la exigencia de hoy.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _RatingRow(
                    icon: Icons.bolt_outlined,
                    label: 'Energía',
                    hint: '1 = muy baja · 5 = excelente',
                    value: energy,
                    onChanged: (value) => setModalState(() => energy = value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RatingRow(
                    icon: Icons.bedtime_outlined,
                    label: 'Sueño',
                    hint: '1 = dormí mal · 5 = muy reparador',
                    value: sleep,
                    onChanged: (value) => setModalState(() => sleep = value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RatingRow(
                    icon: Icons.psychology_alt_outlined,
                    label: 'Estrés',
                    hint: '1 = bajo · 5 = muy alto',
                    value: stress,
                    onChanged: (value) => setModalState(() => stress = value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RatingRow(
                    icon: Icons.accessibility_new_outlined,
                    label: 'Molestia muscular',
                    hint: '1 = mínima · 5 = muy marcada',
                    value: soreness,
                    onChanged: (value) => setModalState(() => soreness = value),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await ref.read(recoveryProvider.notifier).save(
                              energy: energy,
                              sleep: sleep,
                              stress: stress,
                              soreness: soreness,
                            );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.check),
                      label: Text(
                        current == null
                            ? 'Guardar check-in'
                            : 'Actualizar check-in',
                      ),
                    ),
                  ),
                ],
              ),
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
          width: 48,
          height: 48,
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
                'Haz un check-in de 20 segundos antes de entrenar.',
                style: AppTypography.bodySmall.copyWith(
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
    ];
    final visibleTrends = trends.where((item) => item.$2 != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
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
                  Text(
                    checkIn.status.label,
                    style: AppTypography.headlineMedium,
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
              const Icon(Icons.tune, color: AppColors.textSecondary),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          checkIn.recommendation,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        if (visibleTrends.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Divider(color: AppColors.surfaceBorder),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'TENDENCIA RECIENTE',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: visibleTrends
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
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.label, required this.trend});

  final String label;
  final RecoveryMetricTrend trend;

  @override
  Widget build(BuildContext context) {
    final delta = trend.delta;
    final symbol = trend.isStable
        ? '→'
        : delta > 0
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
          ],
        ),
        const SizedBox(height: 3),
        Text(
          hint,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: List.generate(5, (index) {
            final rating = index + 1;
            final selected = rating == value;
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: index == 4 ? 0 : AppSpacing.xs),
                child: InkWell(
                  onTap: () => onChanged(rating),
                  borderRadius: AppRadius.sm_,
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.curve,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          selected ? AppColors.primary : AppColors.surface,
                      borderRadius: AppRadius.sm_,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.surfaceBorder,
                      ),
                    ),
                    child: Text(
                      '$rating',
                      style: AppTypography.labelLarge.copyWith(
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
