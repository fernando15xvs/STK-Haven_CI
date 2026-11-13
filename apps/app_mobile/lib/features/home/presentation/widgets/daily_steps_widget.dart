import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:core/core/services/step_goal_reminder_service.dart';
import 'package:core/domain/models/step_goal_preferences.dart';
import 'package:core/features/home/application/wellness_provider.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:gym_tracker/features/home/application/home_refresh_policy.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:gym_tracker/features/home/application/daily_steps_bridge.dart';

class DailyStepsWidget extends ConsumerStatefulWidget {
  const DailyStepsWidget({
    super.key,
    this.compact = false,
    this.isVisible = true,
  });

  final bool compact;
  final bool isVisible;

  @override
  ConsumerState<DailyStepsWidget> createState() => _DailyStepsWidgetState();
}

class _DailyStepsWidgetState extends ConsumerState<DailyStepsWidget>
    with WidgetsBindingObserver {
  static const Duration _reminderResyncInterval = Duration(minutes: 15);

  Timer? _refreshTimer;
  DateTime? _lastReminderSyncAt;
  bool _busy = false;
  DailyStepsAccessStatus? _accessStatus;
  bool _appResumed = true;

  bool get _canPoll => HomeRefreshPolicy.canPoll(
        visible: widget.isVisible,
        appResumed: _appResumed,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startPolling();
    });
  }

  @override
  void didUpdateWidget(covariant DailyStepsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      if (!widget.isVisible) {
        _refreshTimer?.cancel();
        _refreshTimer = null;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startPolling();
        });
      }
    }
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (!mounted || !_canPoll) return;
    ref.read(dailyStepsProvider.notifier).checkDateAndRefresh();
    // Read already-authorized sensors only. Permission is requested solely
    // from the explicit "Conectar pasos" action.
    _refreshFromDevice();
    _syncGoalReminders();
    final savings =
        ref.read(settingsProvider).performanceMode == PerformanceMode.savings;
    _refreshTimer = Timer.periodic(
      HomeRefreshPolicy.stepRefreshInterval(savings: savings),
      (_) {
        if (!mounted || !_canPoll) return;
        ref.read(dailyStepsProvider.notifier).checkDateAndRefresh();
        _refreshFromDevice();
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (_appResumed == resumed) return;
    _appResumed = resumed;
    if (resumed) {
      _startPolling();
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  Future<void> _refreshFromDevice({bool requestAccess = false}) async {
    if (_busy || !mounted || !_canPoll) return;
    final sampledAt = DateTime.now();
    setState(() => _busy = true);

    try {
      int? steps;

      if (requestAccess) {
        final access = await DailyStepsBridge.requestAccess();
        _accessStatus = access.status;
        if (access.status == DailyStepsAccessStatus.authorized) {
          steps = access.steps ?? await DailyStepsBridge.readTodaySteps();
        }
      } else {
        steps = await DailyStepsBridge.readTodaySteps();
        if (steps != null) {
          _accessStatus = DailyStepsAccessStatus.authorized;
        }
      }

      // A slow sensor response after midnight or after switching tabs must
      // never overwrite the next day's stored count or trigger reminders.
      if (!mounted || !_canPoll ||
          !HomeRefreshPolicy.sameLocalDay(sampledAt, DateTime.now())) {
        return;
      }
      if (steps != null) {
        final preferences = ref.read(stepGoalPreferencesProvider);
        final previous = ref.read(dailyStepsProvider);
        final wasAtTarget = previous.steps >= preferences.targetSteps;
        await ref
            .read(dailyStepsProvider.notifier)
            .setSteps(steps, deviceSynced: true);
        if (!mounted || !_canPoll) return;
        final isAtTarget = steps >= preferences.targetSteps;
        await _syncGoalReminders(force: wasAtTarget != isAtTarget);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncGoalReminders({
    bool requestPermission = false,
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastReminderSyncAt != null &&
        HomeRefreshPolicy.sameLocalDay(_lastReminderSyncAt!, now) &&
        now.difference(_lastReminderSyncAt!) < _reminderResyncInterval) {
      return;
    }

    final state = ref.read(dailyStepsProvider);
    final preferences = ref.read(stepGoalPreferencesProvider);
    final ok = await StepGoalReminderService.syncToday(
      preferences: preferences,
      currentSteps: state.steps,
      lastSyncedAt: state.lastSyncedAt,
      requestPermissionIfNeeded: requestPermission,
    );
    _lastReminderSyncAt = now;

    if (requestPermission && preferences.reminderEnabled && !ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se concedió permiso para los recordatorios de pasos.',
          ),
        ),
      );
    }
  }

  Future<void> _showGoalSettings() async {
    final current = ref.read(stepGoalPreferencesProvider);
    var targetSteps = current.targetSteps;
    var reminderEnabled = current.reminderEnabled;
    var cadence = current.reminderCadence;

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
                    'Meta diaria de pasos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Elige una meta que te sirva como referencia personal. '
                    'No es una recomendación médica.',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Meta: $targetSteps pasos',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Slider(
                    value: targetSteps.toDouble(),
                    min: 1000,
                    max: 50000,
                    divisions: 98,
                    label: '$targetSteps',
                    onChanged: (value) => setSheetState(
                      () => targetSteps = (value / 500).round() * 500,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final preset in const [5000, 7500, 10000, 12000])
                        ChoiceChip(
                          label: Text('$preset'),
                          selected: targetSteps == preset,
                          onSelected: (_) =>
                              setSheetState(() => targetSteps = preset),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Recordarme si todavía no llego a mi meta',
                    ),
                    subtitle: const Text(
                      'Los avisos usan la última sincronización disponible.',
                    ),
                    value: reminderEnabled,
                    onChanged: (value) =>
                        setSheetState(() => reminderEnabled = value),
                  ),
                  if (reminderEnabled) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<StepReminderCadence>(
                      initialValue: cadence,
                      decoration: const InputDecoration(
                        labelText: 'Frecuencia',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: StepReminderCadence.balanced,
                          child: Text('Inteligente · 17:30 y 20:30'),
                        ),
                        DropdownMenuItem(
                          value: StepReminderCadence.gentle,
                          child: Text('Suave · 20:00'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => cadence = value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cadence == StepReminderCadence.balanced
                          ? 'Máximo dos avisos al día. No se usan recordatorios cada hora.'
                          : 'Un solo aviso por la noche.',
                      style: Theme.of(context).textTheme.bodySmall,
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

    final notifier = ref.read(stepGoalPreferencesProvider.notifier);
    await notifier.setTargetSteps(targetSteps);
    await notifier.setReminderCadence(cadence);
    await notifier.setReminderEnabled(reminderEnabled);
    await _syncGoalReminders(requestPermission: reminderEnabled, force: true);

    if (mounted) setState(() {});
  }

  String _deviceStatusText(bool deviceSynced) {
    if (_busy) return 'Actualizando automáticamente…';

    if (deviceSynced && _accessStatus == DailyStepsAccessStatus.authorized) {
      return 'Se actualiza automáticamente desde el dispositivo.';
    }

    return switch (_accessStatus) {
      DailyStepsAccessStatus.denied =>
        'Permiso de actividad/movimiento desactivado en Ajustes.',
      DailyStepsAccessStatus.restricted =>
        'El acceso al sensor de movimiento está restringido.',
      DailyStepsAccessStatus.unavailable =>
        'El contador de pasos no está disponible en este dispositivo.',
      DailyStepsAccessStatus.notDetermined =>
        'Esperando permiso del sistema para leer pasos.',
      DailyStepsAccessStatus.queryFailed =>
        'No se pudo leer el sensor de pasos.',
      DailyStepsAccessStatus.authorized =>
        'Conectado al contador de pasos del dispositivo.',
      null => 'Conectando con el contador de pasos…',
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((settings) => settings.performanceMode),
        (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _canPoll) _startPolling();
      });
    });
    final state = ref.watch(dailyStepsProvider);
    final preferences = ref.watch(stepGoalPreferencesProvider);
    final colors = AppColors.of(context);
    final target = preferences.targetSteps;
    final remaining = (target - state.steps).clamp(0, target).toInt();
    final progress = target <= 0
        ? 0.0
        : (state.steps / target).clamp(0.0, 1.0).toDouble();
    final format = NumberFormat.decimalPattern('es');

    return PremiumCard(
      key: const ValueKey('home_steps_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_walk_rounded, color: colors.primary, size: 21),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text('Pasos', style: AppTypography.labelLarge)),
              IconButton(
                tooltip: 'Configurar meta y recordatorios de pasos',
                onPressed: _showGoalSettings,
                icon: const Icon(Icons.tune_rounded, size: 20),
                color: colors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            format.format(state.steps),
            style: AppTypography.headlineMedium.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            'Meta: ${format.format(target)} pasos',
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
              semanticsLabel: 'Progreso de pasos',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Tooltip(
            message: _deviceStatusText(state.deviceSynced),
            child: Text(
              widget.compact
                  ? state.deviceSynced
                      ? 'Desde el dispositivo'
                      : 'Sin sincronizar'
                  : _deviceStatusText(state.deviceSynced),
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          if (!state.deviceSynced &&
              _accessStatus != DailyStepsAccessStatus.authorized) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('home_steps_connect'),
                onPressed: _busy ? null : () {
                  _refreshFromDevice(requestAccess: true);
                },
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text('Conectar pasos',
                    style: AppTypography.labelMedium),
              ),
            ),
          ],
          if (!widget.compact) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              remaining == 0
                  ? 'Meta completada por hoy.'
                  : 'Te faltan ${format.format(remaining)} pasos para tu meta.',
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            if (preferences.reminderEnabled) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                preferences.reminderCadence == StepReminderCadence.balanced
                    ? 'Recordatorios: 17:30 y 20:30.'
                    : 'Recordatorio: 20:00.',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
