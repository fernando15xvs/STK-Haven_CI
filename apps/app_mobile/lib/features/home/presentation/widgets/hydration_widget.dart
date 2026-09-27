import 'package:core/core/services/hydration_reminder_service.dart';
import 'package:core/features/home/application/hydration_provider.dart';
import 'package:core/features/home/application/wellness_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

class HydrationWidget extends ConsumerStatefulWidget {
  const HydrationWidget({super.key});

  @override
  ConsumerState<HydrationWidget> createState() => _HydrationWidgetState();
}

class _HydrationWidgetState extends ConsumerState<HydrationWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(hydrationProvider.notifier).checkDateAndRefresh();
      await _syncReminder();
    });
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
                            child: Text('${hour.toString().padLeft(2, '0')}:00'),
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
    await ref
        .read(hydrationPreferencesProvider.notifier)
        .setTargetMl(targetMl);
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
    final hydration = ref.watch(hydrationProvider);
    final preferences = ref.watch(hydrationPreferencesProvider);
    final targetMl = preferences.targetMl;
    final remaining = (targetMl - hydration.waterMl).clamp(0, targetMl);
    final progress =
        targetMl <= 0 ? 0.0 : (hydration.waterMl / targetMl).clamp(0.0, 1.0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.water_drop, color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Hidratación diaria',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Configurar meta y recordatorio',
                  onPressed: _showSettings,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            Text(
              '${hydration.waterMl} / $targetMl ml',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: AppColors.surfaceBorder,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              remaining == 0
                  ? 'Meta registrada por hoy.'
                  : 'Te faltan $remaining ml para tu meta personal.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (preferences.reminderEnabled) ...[
              const SizedBox(height: 4),
              Text(
                'Recordatorio: ${preferences.reminderHour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _addButton('+250 ml', 250),
                _addButton('+500 ml', 500),
                _addButton('+750 ml', 750),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _addButton(String label, int ml) {
    return OutlinedButton(
      onPressed: () => _addWater(ml),
      child: Text(label),
    );
  }
}
