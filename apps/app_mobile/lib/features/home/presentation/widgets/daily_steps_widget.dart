import 'dart:async';

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

  Timer? _refreshTimer;
  bool _busy = false;
  DailyStepsAccessStatus? _accessStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyStepsProvider.notifier).checkDateAndRefresh();
      _refreshFromDevice(requestAccess: true);
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
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusText(bool deviceSynced) {
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pasos de hoy',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.steps} pasos',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _statusText(state.deviceSynced),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (_busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                state.deviceSynced
                    ? Icons.check_circle_outline_rounded
                    : Icons.directions_walk_rounded,
                color: state.deviceSynced
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
