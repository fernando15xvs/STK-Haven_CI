import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/recovery/application/recovery_history.dart';
import 'package:core/features/recovery/application/recovery_performance_correlation.dart';
import 'package:core/features/recovery/application/recovery_provider.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';

import 'recovery_history_sheet.dart';
import 'package:core/features/recovery/application/sleep_diary.dart';
import 'package:core/features/recovery/application/adaptive_recovery.dart';
import 'home_sleep_card.dart';

enum RecoveryCheckInTiming { planned, active, completed }

class RecoveryCheckInCard extends ConsumerWidget {
  const RecoveryCheckInCard({
    super.key,
    this.compact = false,
    this.trainingContext = RecoveryCheckInTiming.planned,
  });

  final bool compact;
  final RecoveryCheckInTiming trainingContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkIn = ref.watch(recoveryProvider);
    final history = ref.watch(recoveryHistoryProvider);
    final snapshot = RecoveryHistorySnapshot.fromEntries(history);
    final performance = ref.watch(recoveryPerformanceProvider);
    final onHistory = history.isEmpty
        ? null
        : () {
            showRecoveryHistorySheet(context, history, performance,
              sleep: ref.read(sleepDiaryProvider));
          };

    return PremiumCard(
      onTap: () => _showCheckInSheet(context, ref, checkIn),
      borderColor: _statusColor(context, checkIn).withValues(alpha: 0.32),
      child: checkIn == null
          ? _EmptyRecoveryState(
              onHistory: onHistory,
              compact: compact,
              trainingContext: trainingContext,
            )
          : _RecoverySummary(
              checkIn: checkIn,
              history: snapshot,
              onHistory: onHistory,
              compact: compact,
            ),
    );
  }

  Future<void> _showCheckInSheet(
    BuildContext context,
    WidgetRef ref,
    RecoveryCheckIn? current,
  ) async {
    final today = DateTime.now();
    var energy = current?.energy;
    var stress = current?.stress;
    var soreness = current?.soreness;
    final areas = <String>{...?current?.fatiguedAreas};
    var pain = current?.painReported ?? false;
    var busy = false;
    String? error;
    var diary = ref.read(sleepDiaryProvider);
    int? sleep = diary.qualityFor(today) ?? current?.sleep;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.of(context).surfaceHigh,
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
                        color: AppColors.of(context).textDisabled,
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
                    'Tu descanso y cómo te sientes ayudan a orientar la exigencia de hoy.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _RatingRow(
                    icon: Icons.bolt_outlined,
                    label: 'Energía',
                    hint: '1 = muy baja · 5 = excelente',
                    value: energy,
                    onChanged: (value) { if (!busy) setModalState(() => energy = value); },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Material(
                    color: AppColors.of(context).surface,
                    borderRadius: AppRadius.md_,
                    child: ListTile(
                      leading: Icon(Icons.bedtime_outlined, color: AppColors.of(context).primary),
                      title: const Text('Sueño'),
                      subtitle: Text([
                        if (diary.minutesFor(today) != null)
                          '${diary.minutesFor(today)! ~/ 60} h ${diary.minutesFor(today)! % 60} min'
                        else 'Duración sin registrar',
                        if (sleep != null) 'Calidad $sleep/5' else 'Calidad pendiente',
                      ].join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: busy ? null : () async {
                        await showSleepDiarySheet(context, today);
                        if (!context.mounted) return;
                        final updated = ref.read(sleepDiaryProvider);
                        setModalState(() {
                          diary = updated;
                          sleep = updated.qualityFor(today) ?? sleep;
                        });
                      },
                    ),
                  ),
                  if (sleep == null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _RatingRow(
                      icon: Icons.bedtime_outlined,
                      label: 'Calidad del sueño',
                      hint: '1 = poco reparador · 5 = muy reparador',
                      value: sleep,
                      onChanged: (value) { if (!busy) setModalState(() => sleep = value); },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _RatingRow(
                    icon: Icons.psychology_alt_outlined,
                    label: 'Estrés',
                    hint: '1 = bajo · 5 = muy alto',
                    value: stress,
                    onChanged: (value) { if (!busy) setModalState(() => stress = value); },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RatingRow(
                    icon: Icons.accessibility_new_outlined,
                    label: 'Fatiga muscular',
                    hint: '1 = mínima · 5 = muy marcada',
                    value: soreness,
                    onChanged: (value) { if (!busy) setModalState(() => soreness = value); },
                  ),
                  if ((soreness ?? 0) >= 2) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('Zonas fatigadas (opcional)', style: AppTypography.headlineSmall),
                    Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
                      for (final area in AdaptiveRecovery.areas)
                        FilterChip(label: Text(area), selected: areas.contains(area),
                          onSelected: busy ? null : (selected) => setModalState(() {
                            if (selected) { areas.add(area); } else { areas.remove(area); }
                          })),
                    ]),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dolor o lesión, distinto de la fatiga habitual'),
                    value: pain,
                    onChanged: busy ? null : (v) => setModalState(() => pain = v),
                  ),
                  if (pain) const Text('Evita los movimientos que provocan dolor y busca valoración profesional si es intenso o persistente.'),
                  if (error != null) Text(error!, style: TextStyle(color: AppColors.of(context).error)),
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy || energy == null || sleep == null || stress == null || soreness == null
                        ? null : () async {
                        setModalState(() { busy = true; error = null; });
                        try {
                          if (diary.qualityFor(today) != sleep) {
                            await ref.read(sleepDiaryProvider.notifier).saveQuality(today, sleep!);
                          }
                        await ref
                            .read(recoveryProvider.notifier)
                            .save(
                              energy: energy!,
                              sleep: sleep!,
                              stress: stress!,
                              soreness: soreness!,
                              fatiguedAreas: soreness! >= 2 ? areas.toList() : const [],
                              painReported: pain,
                            );
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        } catch (_) {
                          if (context.mounted) setModalState(() {
                            busy = false; error = 'No se pudo guardar. Inténtalo de nuevo.';
                          });
                        }
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

  static Color _statusColor(BuildContext context, RecoveryCheckIn? checkIn) {
    if (checkIn == null) return AppColors.of(context).primary;
    return switch (checkIn.status) {
      RecoveryStatus.ready => AppColors.of(context).success,
      RecoveryStatus.moderate => AppColors.of(context).warning,
      RecoveryStatus.low => AppColors.of(context).error,
    };
  }
}

class _EmptyRecoveryState extends StatelessWidget {
  final VoidCallback? onHistory;
  final bool compact;
  final RecoveryCheckInTiming trainingContext;

  const _EmptyRecoveryState({
    this.onHistory,
    this.compact = false,
    this.trainingContext = RecoveryCheckInTiming.planned,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      final hint = switch (trainingContext) {
        RecoveryCheckInTiming.active => 'Revisa cómo te sientes durante tu sesión.',
        RecoveryCheckInTiming.completed => 'Registra cómo te sientes después de entrenar.',
        RecoveryCheckInTiming.planned => 'Check-in rápido · 20 segundos',
      };
      return Row(
        children: [
          Icon(Icons.favorite_border_rounded,
              size: 24, color: AppColors.of(context).primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Cómo está tu cuerpo hoy?',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onHistory != null)
            IconButton(
              tooltip: 'Ver historial de recuperación',
              onPressed: onHistory,
              icon: Icon(Icons.insights_outlined,
                  color: AppColors.of(context).primary),
            )
          else
            Icon(Icons.chevron_right,
                color: AppColors.of(context).textSecondary),
        ],
      );
    }
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.of(context).primaryFaded,
            borderRadius: AppRadius.md_,
          ),
          child: Icon(
            Icons.favorite_outline,
            color: AppColors.of(context).primary,
          ),
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
                  color: AppColors.of(context).textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (onHistory != null)
          IconButton(
            tooltip: 'Ver historial de recuperación',
            onPressed: onHistory,
            icon: Icon(
              Icons.insights_outlined,
              color: AppColors.of(context).primary,
            ),
          )
        else
          Icon(Icons.chevron_right, color: AppColors.of(context).textSecondary),
      ],
    );
  }
}

class _RecoverySummary extends StatelessWidget {
  final RecoveryCheckIn checkIn;
  final RecoveryHistorySnapshot history;
  final VoidCallback? onHistory;
  final bool compact;

  const _RecoverySummary({
    required this.checkIn,
    required this.history,
    this.onHistory,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (checkIn.status) {
      RecoveryStatus.ready => AppColors.of(context).success,
      RecoveryStatus.moderate => AppColors.of(context).warning,
      RecoveryStatus.low => AppColors.of(context).error,
    };
    final trends = <(String, RecoveryMetricTrend?)>[
      ('Energía', history.energyTrend),
      ('Sueño', history.sleepTrend),
      ('Estrés', history.stressTrend),
      ('Molestia', history.sorenessTrend),
    ];
    final visibleTrends = trends.where((item) => item.$2 != null).toList();

    // The Home overview is a single status row; full trend/recommendation
    // detail remains available through recovery's original paths.
    if (compact) {
      return Row(
        children: [
          Icon(Icons.favorite_rounded, size: 24, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recuperación de hoy',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                Text('${checkIn.status.label} · ${checkIn.score}/100',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.of(context).textSecondary,
                    )),
              ],
            ),
          ),
          if (onHistory != null)
            IconButton(
              tooltip: 'Ver historial de recuperación',
              onPressed: onHistory,
              icon: Icon(Icons.insights_outlined,
                  color: AppColors.of(context).primary),
            )
          else
            Icon(Icons.chevron_right,
                color: AppColors.of(context).textSecondary),
        ],
      );
    }

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
                    backgroundColor: AppColors.of(context).surfaceBorder,
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
                icon: Icon(
                  Icons.insights_outlined,
                  color: AppColors.of(context).primary,
                ),
              )
            else
              Icon(Icons.tune, color: AppColors.of(context).textSecondary),
          ],
        ),
        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
        Text(
          checkIn.recommendation,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.of(context).textSecondary,
            height: 1.45,
          ),
        ),
        if (!compact && visibleTrends.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Divider(color: AppColors.of(context).surfaceBorder),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'TENDENCIA RECIENTE',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: visibleTrends
                .map((item) => _TrendChip(label: item.$1, trend: item.$2!))
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
        color: AppColors.of(context).surfaceHigh,
        borderRadius: AppRadius.sm_,
        border: Border.all(color: AppColors.of(context).surfaceBorder),
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
  final int? value;
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
            Icon(icon, size: 20, color: AppColors.of(context).primary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(label, style: AppTypography.headlineSmall)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          hint,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.of(context).textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: List.generate(5, (index) {
            final rating = index + 1;
            final selected = rating == value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 4 ? 0 : AppSpacing.xs),
                child: InkWell(
                  onTap: () => onChanged(rating),
                  borderRadius: AppRadius.sm_,
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.curve,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.of(context).primary
                          : AppColors.of(context).surface,
                      borderRadius: AppRadius.sm_,
                      border: Border.all(
                        color: selected
                            ? AppColors.of(context).primary
                            : AppColors.of(context).surfaceBorder,
                      ),
                    ),
                    child: Text(
                      '$rating',
                      style: AppTypography.labelLarge.copyWith(
                        color: selected
                            ? AppColors.of(context).onPrimary
                            : AppColors.of(context).textSecondary,
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
