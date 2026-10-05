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

class _DailyStepsWidgetState extends ConsumerState<DailyStepsWidget> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyStepsProvider.notifier).checkDateAndRefresh();
    });
  }

  Future<void> _syncDevice() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final access = await DailyStepsBridge.requestAccess();
      if (access.status != DailyStepsAccessStatus.authorized) {
        if (mounted) {
          final message = switch (access.status) {
            DailyStepsAccessStatus.denied =>
              'STK Haven no tiene permiso de Movimiento y condición física. '
                  'Actívalo en Ajustes > Privacidad y seguridad > '
                  'Movimiento y condición física.',
            DailyStepsAccessStatus.restricted =>
              'El acceso a Movimiento y condición física está restringido '
                  'por el sistema o por controles del dispositivo.',
            DailyStepsAccessStatus.unavailable =>
              'Este iPhone no ofrece conteo de pasos mediante Core Motion.',
            DailyStepsAccessStatus.notDetermined =>
              'iOS todavía no resolvió el permiso de movimiento. '
                  'Vuelve a intentarlo después de responder al aviso del sistema.',
            DailyStepsAccessStatus.queryFailed =>
              'No se pudo leer Core Motion. Verifica que Seguimiento de '
                  'condición física esté activado en Ajustes.',
            DailyStepsAccessStatus.authorized => '',
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
        return;
      }
      final steps = access.steps ?? await DailyStepsBridge.readTodaySteps();
      if (steps == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El permiso está activo, pero iOS no devolvió pasos de hoy.',
              ),
            ),
          );
        }
        return;
      }
      await ref
          .read(dailyStepsProvider.notifier)
          .setSteps(steps, deviceSynced: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editManually() async {
    final current = ref.read(dailyStepsProvider).steps;
    final controller = TextEditingController(text: '$current');
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar pasos'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Pasos de hoy',
            hintText: 'Ej. 4500',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              int.tryParse(controller.text.trim()),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      await ref.read(dailyStepsProvider.notifier).setSteps(value);
    }
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                    state.deviceSynced
                        ? 'Sincronizado con el dispositivo'
                        : 'Sincroniza el sensor o registra el dato manualmente.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: state.deviceSynced
                      ? 'Actualizar pasos'
                      : 'Conectar pasos del dispositivo',
                  onPressed: _busy ? null : _syncDevice,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                ),
                IconButton(
                  tooltip: 'Registrar manualmente',
                  onPressed: _editManually,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
