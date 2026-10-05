import 'dart:async';

import 'package:core/core/services/step_goal_reminder_service.dart';
import 'package:core/domain/models/step_goal_preferences.dart';
import 'package:core/features/home/application/wellness_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/home/application/daily_steps_bridge.dart';

class DailyStepsWidget extends ConsumerStatefulWidget {
  const DailyStepsWidget({super.key});

  @override
  ConsumerState<DailyStepsWidget> createState() => _DailyStepsWidgetState();
}

class _DailyStepsWidgetState extends ConsumerState<DailyStepsWidget>
    with WidgetsBindingObserver {
  static const Duration _refreshInterval = Duration(minutes: 1);
  static const Duration _reminderResyncInterval = Duration(minutes: 15);

  Timer? _refreshTimer;
  DateTime? _lastReminderSyncAt;
  bool _busy = false;
  DailyStepsAccessStatus? _accessStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(dailyStepsProvider.notifier).checkDateAndRefresh();
      await _refreshFromDevice(requestAccess: true);
      await _syncGoalReminders(force: true);
      _refreshTimer = Timer.periodic(_refreshInterval, (_) {
        ref.read(dailyStepsProvider.notifier).checkDateAndRefresh();
        _refreshFromDevice();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.read(dailyStepsProvider.notifier).checkDateAndRefresh();
    _refreshFromDevice();
  }

  Future<void> _refreshFromDevice({bool requestAccess = false}) async {
    if (_busy || !mounted) return;
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

      if (steps != null) {
        await ref
            .read(dailyStepsProvider.notifier)
            .setSteps(steps, deviceSynced: true);

        final preferences = ref.read(stepGoalPreferencesProvider);
        await _syncGoalReminders(
          force: steps >= preferences.targetSteps,
        );
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

    if (requestPermission &&
        preferences.reminderEnabled &&
        !ok &&
        mounted) {
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
                      () => targetSteps =
                          (value / 500).round() * 500,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final preset in const [5000, 7500, 10000, 12000])
                        ChoiceChip(
                          label: Text('$preset'),
                          selected: targetSteps == preset,
                          onSelected: (_) => setSheetState(
                            () => targetSteps = preset,
                          ),
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
                          child: Text(
                            'Inteligente · 17:30 y 20:30',
                          ),
                        ),
                        DropdownMenuItem(
                          value: StepReminderCadence.gentle,
                          child: Text(
                            'Suave · 20:00',
                          ),
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
    await _syncGoalReminders(
      requestPermission: reminderEnabled,
      force: true,
    );

    if (mounted) setState(() {});
  }

  String _deviceStatusText(bool deviceSynced) {
    if (_busy) return 'Actualizando automáticamente…';

    if (deviceSynced &&
        _accessStatus == DailyStepsAccessStatus.authorized) {
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
    final state = ref.watch(dailyStepsProvider);
    final preferences = ref.watch(stepGoalPreferencesProvider);
    final target = preferences.targetSteps;
    final remaining = (target - state.steps).clamp(0, target).toInt();
    final progress = target <= 0
        ? 0.0
        : (state.steps / target).clamp(0.0, 1.0).toDouble();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryFaded,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.directions_walk_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Pasos de hoy',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Configurar meta y recordatorios',
                  onPressed: _showGoalSettings,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${state.steps} / $target pasos',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: AppColors.surfaceBorder,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              remaining == 0
                  ? 'Meta completada por hoy.'
                  : 'Te faltan $remaining pasos para tu meta.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _deviceStatusText(state.deviceSynced),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (preferences.reminderEnabled) ...[
              const SizedBox(height: 4),
              Text(
                preferences.reminderCadence ==
                        StepReminderCadence.balanced
                    ? 'Recordatorios inteligentes: 17:30 y 20:30.'
                    : 'Recordatorio suave: 20:00.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
