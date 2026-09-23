import 'package:core/features/recovery/application/recovery_history.dart';
import 'package:core/features/recovery/application/recovery_performance_correlation.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

Future<void> showRecoveryHistorySheet(
  BuildContext context,
  List<RecoveryCheckIn> entries,
  RecoveryPerformanceInsight performance,
) async {
  final history = RecoveryHistorySnapshot.fromEntries(entries);
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.84,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryFaded,
                  borderRadius: AppRadius.md_,
                ),
                child: const Icon(
                  Icons.insights_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historial de recuperación',
                      style: AppTypography.headlineLarge,
                    ),
                    Text(
                      'Tus últimos ${history.completedDays} check-ins',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (history.isEmpty)
            const _EmptyHistory()
          else ...[
            _SummaryStrip(history: history),
            const SizedBox(height: AppSpacing.md),
            _ScoreChart(history: history, maxPoints: 7),
            const SizedBox(height: AppSpacing.md),
            _PerformanceCorrelationCard(insight: performance),
            const SizedBox(height: AppSpacing.xl),
            Text('Detalle diario', style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            ...history.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _HistoryEntryCard(entry: entry),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}


class _PerformanceCorrelationCard extends StatelessWidget {
  final RecoveryPerformanceInsight insight;

  const _PerformanceCorrelationCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final color = _associationColor(insight.association);
    final minimum = RecoveryPerformanceInsight.minimumComparableSessions;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.md_,
                ),
                child: Icon(Icons.compare_arrows_rounded, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recuperación vs rendimiento',
                      style: AppTypography.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cambio de volumen frente a la sesión anterior de la misma rutina.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!insight.hasEnoughData) ...[
            Text(
              'El análisis aparecerá al existir al menos $minimum sesiones comparables con check-in el mismo día.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: insight.comparableSessions / minimum,
              minHeight: 7,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: AppColors.surfaceBorder,
              color: color,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${insight.comparableSessions}/$minimum comparaciones · faltan ${insight.missingComparisons}',
              style: AppTypography.labelSmall.copyWith(color: color),
            ),
          ] else ...[
            Text(
              _associationLabel(insight.association),
              style: AppTypography.labelLarge.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              _associationSummary(insight.association),
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _CorrelationMetric(
                  label: 'COEFICIENTE',
                  value: 'r ${(insight.coefficient ?? 0).toStringAsFixed(2)}',
                  color: color,
                ),
                _CorrelationMetric(
                  label: 'CAMBIO MEDIO',
                  value: _signedPercent(
                    insight.averageVolumeChangePercent,
                  ),
                  color: AppColors.info,
                ),
                _CorrelationMetric(
                  label: 'COMPARACIONES',
                  value: '${insight.comparableSessions}',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...insight.points.take(3).map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_compactDate(point.date)} · ${point.routineName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${point.recoveryScore}/100',
                      style: AppTypography.labelSmall.copyWith(
                        color: _statusColor(point.recoveryStatus),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _signedPercent(point.volumeChangePercent),
                      style: AppTypography.labelSmall.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Divider(color: AppColors.surfaceBorder),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Asociación histórica; no demuestra causa ni recomienda aumentar carga o entrenar con molestias.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textDisabled,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _CorrelationMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CorrelationMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.sm_,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label · $value',
        style: AppTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final RecoveryHistorySnapshot history;

  const _SummaryStrip({required this.history});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'PROMEDIO',
            value: '${history.averageScore}',
            color: _scoreColor(history.averageScore),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _MetricCard(
            label: 'MEJOR',
            value: '${history.bestScore}',
            color: _scoreColor(history.bestScore),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _MetricCard(
            label: 'REGISTROS',
            value: '${history.completedDays}',
            color: AppColors.info,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.md_,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.monoLarge.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ScoreChart extends StatelessWidget {
  final RecoveryHistorySnapshot history;
  final int maxPoints;

  const _ScoreChart({
    required this.history,
    required this.maxPoints,
  });

  @override
  Widget build(BuildContext context) {
    final allPoints = history.chronological;
    final start = allPoints.length > maxPoints
        ? allPoints.length - maxPoints
        : 0;
    final points = allPoints.sublist(start);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Puntaje por check-in', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 142,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((entry) {
                final color = _statusColor(entry.status);
                final barHeight = 24 + (entry.score * 0.72);
                return Expanded(
                  child: Tooltip(
                    message:
                        '${_dateLabel(entry.date)} · ${entry.score}/100',
                    child: Semantics(
                      label:
                          '${_dateLabel(entry.date)}, recuperación ${entry.score} de 100',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${entry.score}',
                              style: AppTypography.labelSmall.copyWith(
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: AppMotion.standard,
                              curve: AppMotion.curve,
                              width: double.infinity,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.78),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppRadius.xs),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _compactDate(entry.date),
                              maxLines: 1,
                              style: AppTypography.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusLegend(history: history),
        ],
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  final RecoveryHistorySnapshot history;

  const _StatusLegend({required this.history});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: RecoveryStatus.values.map((status) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _statusColor(status),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${_shortStatus(status)} ${history.countFor(status)}',
              style: AppTypography.bodySmall,
            ),
          ],
        );
      }).toList(growable: false),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final RecoveryCheckIn entry;

  const _HistoryEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(entry.status);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.md_,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  '${entry.score}',
                  style: AppTypography.monoMedium.copyWith(color: color),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateLabel(entry.date),
                      style: AppTypography.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.status.label,
                      style: AppTypography.bodySmall.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              Text('/100', style: AppTypography.labelSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _MetricBadge(label: 'Energía', value: entry.energy),
              _MetricBadge(label: 'Sueño', value: entry.sleep),
              _MetricBadge(label: 'Estrés', value: entry.stress),
              _MetricBadge(label: 'Molestia', value: entry.soreness),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final int value;

  const _MetricBadge({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.sm_,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Text(
        '$label $value',
        style: AppTypography.labelSmall,
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg_,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.insights_outlined,
            size: 42,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Aún no hay historial',
            style: AppTypography.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Completa tu primer check-in para comenzar a ver la evolución.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

Color _scoreColor(int score) {
  if (score >= 75) return AppColors.success;
  if (score >= 55) return AppColors.warning;
  return AppColors.error;
}

Color _statusColor(RecoveryStatus status) {
  return switch (status) {
    RecoveryStatus.ready => AppColors.success,
    RecoveryStatus.moderate => AppColors.warning,
    RecoveryStatus.low => AppColors.error,
  };
}

String _shortStatus(RecoveryStatus status) {
  return switch (status) {
    RecoveryStatus.ready => 'Listo',
    RecoveryStatus.moderate => 'Moderado',
    RecoveryStatus.low => 'Bajo',
  };
}

String _compactDate(DateTime date) => '${date.day}/${date.month}';

String _dateLabel(DateTime date) {
  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final normalizedDate = DateTime(date.year, date.month, date.day);
  final difference = normalizedToday.difference(normalizedDate).inDays;
  if (difference == 0) return 'Hoy';
  if (difference == 1) return 'Ayer';

  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]}';
}


Color _associationColor(RecoveryPerformanceAssociation association) {
  return switch (association) {
    RecoveryPerformanceAssociation.insufficient => AppColors.textSecondary,
    RecoveryPerformanceAssociation.positive => AppColors.success,
    RecoveryPerformanceAssociation.neutral => AppColors.info,
    RecoveryPerformanceAssociation.inverse => AppColors.warning,
  };
}

String _associationLabel(RecoveryPerformanceAssociation association) {
  return switch (association) {
    RecoveryPerformanceAssociation.insufficient => 'Datos insuficientes',
    RecoveryPerformanceAssociation.positive => 'Asociación positiva',
    RecoveryPerformanceAssociation.neutral => 'Sin patrón claro',
    RecoveryPerformanceAssociation.inverse => 'Asociación inversa',
  };
}

String _associationSummary(RecoveryPerformanceAssociation association) {
  return switch (association) {
    RecoveryPerformanceAssociation.insufficient =>
      'Todavía no hay suficientes comparaciones para describir un patrón.',
    RecoveryPerformanceAssociation.positive =>
      'En estos registros, puntajes más altos coincidieron con mayores cambios de volumen.',
    RecoveryPerformanceAssociation.neutral =>
      'En estos registros no aparece una relación consistente entre ambas medidas.',
    RecoveryPerformanceAssociation.inverse =>
      'En estos registros, puntajes más altos coincidieron con menores cambios de volumen.',
  };
}

String _signedPercent(double value) {
  final prefix = value > 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(1)}%';
}
