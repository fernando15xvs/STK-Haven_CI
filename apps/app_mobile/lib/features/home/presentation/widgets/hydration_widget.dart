import 'package:core/core/services/hydration_reminder_service.dart';
import 'package:gym_tracker/features/home/application/home_refresh_policy.dart';
import 'package:core/features/home/application/hydration_provider.dart';
import 'package:core/features/home/application/wellness_provider.dart';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';

class HydrationWidget extends ConsumerStatefulWidget {
  const HydrationWidget({
    super.key,
    this.compact = false,
    this.isVisible = true,
  });

  final bool compact;
  final bool isVisible;

  @override
  ConsumerState<HydrationWidget> createState() => _HydrationWidgetState();
}

class _HydrationWidgetState extends ConsumerState<HydrationWidget>
    with WidgetsBindingObserver {
  bool _appResumed = true;

  bool get _canRefresh => HomeRefreshPolicy.canPoll(
        visible: widget.isVisible,
        appResumed: _appResumed,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshForToday();
    });
  }

  @override
  void didUpdateWidget(covariant HydrationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isVisible && widget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshForToday();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_canRefresh) _refreshForToday();
  }

  void _refreshForToday() {
    if (!mounted || !_canRefresh) return;
    ref.read(hydrationProvider.notifier).checkDateAndRefresh();
    _syncReminder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _syncReminder({bool requestPermission = false}) async {
    final hydration = ref.read(hydrationProvider);
    final preferences = ref.read(hydrationPreferencesProvider);
    final granted = await HydrationReminderService.syncNextReminder(
      enabled: preferences.reminderEnabled,
      currentMl: hydration.waterMl,
      targetMl: preferences.targetMl,
      reminderHour: preferences.reminderHour,
      requestPermissionIfNeeded: requestPermission,
    );
    if (requestPermission &&
        preferences.reminderEnabled &&
        !granted &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se concedió permiso para recordatorios de hidratación.',
          ),
        ),
      );
    }
  }

  Future<void> _addWater(int ml) async {
    ref.read(hydrationProvider.notifier).addWater(ml);
    await _syncReminder();
  }

  Future<void> _showSettings() async {
    final current = ref.read(hydrationPreferencesProvider);
    var targetMl = current.targetMl;
    var reminderEnabled = current.reminderEnabled;
    var reminderHour = current.reminderHour;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configurar hidratación',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'La meta es personalizable y sirve solo como referencia de registro; no es una recomendación médica.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Meta diaria: ${(targetMl / 1000).toStringAsFixed(targetMl % 1000 == 0 ? 0 : 2)} L',
                  ),
                  Slider(
                    value: targetMl.toDouble(),
                    min: 1000,
                    max: 5000,
                    divisions: 16,
                    label: '$targetMl ml',
                    onChanged: (value) =>
                        setSheetState(() => targetMl = value.round()),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recordarme si aún no llego a mi meta'),
                    value: reminderEnabled,
                    onChanged: (value) =>
                        setSheetState(() => reminderEnabled = value),
                  ),
                  if (reminderEnabled) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: reminderHour,
                      decoration: const InputDecoration(
                        labelText: 'Hora del recordatorio',
                      ),
                      items: [
                        for (final hour in [12, 15, 18, 20, 22])
                          DropdownMenuItem(
                            value: hour,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => reminderHour = value);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (saved != true) return;
    await ref.read(hydrationPreferencesProvider.notifier).setTargetMl(targetMl);
    await ref
        .read(hydrationPreferencesProvider.notifier)
        .setReminderHour(reminderHour);
    await ref
        .read(hydrationPreferencesProvider.notifier)
        .setReminderEnabled(reminderEnabled);
    await _syncReminder(requestPermission: reminderEnabled);
  }

  @override
  Widget build(BuildContext context) {
    // Dashboard refreshes daily totals at midnight even when this tile is
    // retained. Reschedule its reminder on the new day only if visible.
    ref.listen(hydrationProvider.select((state) => state.dateString),
        (previous, next) {
      if (previous != next && _canRefresh) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _canRefresh) _syncReminder();
        });
      }
    });
    final hydration = ref.watch(hydrationProvider);
    final preferences = ref.watch(hydrationPreferencesProvider);
    final colors = AppColors.of(context);
    final targetMl = preferences.targetMl;
    final remaining = (targetMl - hydration.waterMl).clamp(0, targetMl);
    final progress = targetMl <= 0
        ? 0.0
        : (hydration.waterMl / targetMl).clamp(0.0, 1.0);
    final format = NumberFormat.decimalPattern('es');

    return PremiumCard(
      key: const ValueKey('home_hydration_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_outlined, color: colors.primary, size: 21),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  widget.compact ? 'Agua' : 'Hidratación diaria',
                  style: AppTypography.labelLarge,
                ),
              ),
              IconButton(
                tooltip: 'Configurar hidratación y recordatorios',
                onPressed: _showSettings,
                icon: const Icon(Icons.tune_rounded, size: 20),
                color: colors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${format.format(hydration.waterMl)} ml',
            style: AppTypography.headlineMedium.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            'Meta: ${format.format(targetMl)} ml',
            style: AppTypography.labelSmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.sm_,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: colors.surfaceBorder,
              color: colors.primary,
              semanticsLabel: 'Progreso de hidratación',
            ),
          ),
          if (!widget.compact) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              remaining == 0
                  ? 'Meta registrada por hoy.'
                  : 'Te faltan ${format.format(remaining)} ml para tu meta.',
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            if (preferences.reminderEnabled) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Recordatorio: ${preferences.reminderHour.toString().padLeft(2, '0')}:00',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          if (widget.compact)
            Wrap(
              spacing: 4,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  key: const ValueKey('home_hydration_quick_add'),
                  onPressed: () => _addWater(250),
                  child: const Text('+250 ml'),
                ),
                PopupMenuButton<int>(
                  tooltip: 'Más cantidades de agua',
                  icon: Icon(Icons.more_horiz, color: colors.textSecondary),
                  onSelected: _addWater,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 500, child: Text('Añadir 500 ml')),
                    PopupMenuItem(value: 750, child: Text('Añadir 750 ml')),
                  ],
                ),
              ],
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _addButton('+250 ml', 250),
                _addButton('+500 ml', 500),
                _addButton('+750 ml', 750),
              ],
            ),
        ],
      ),
    );
  }

  Widget _addButton(String label, int ml) {
    return OutlinedButton(
      onPressed: () => _addWater(ml),
      child: Text(label, style: AppTypography.labelMedium),
    );
  }
}
