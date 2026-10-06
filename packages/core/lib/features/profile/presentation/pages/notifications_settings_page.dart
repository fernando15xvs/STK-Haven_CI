import 'package:core/core/services/hydration_reminder_service.dart';
import 'package:core/core/services/step_goal_reminder_service.dart';
import 'package:core/domain/models/step_goal_preferences.dart';
import 'package:core/features/home/application/hydration_provider.dart';
import 'package:core/features/home/application/wellness_provider.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationsSettingsPage extends ConsumerWidget {
  const NotificationsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final hydration = ref.watch(hydrationProvider);
    final hydrationPrefs = ref.watch(hydrationPreferencesProvider);
    final stepState = ref.watch(dailyStepsProvider);
    final stepPrefs = ref.watch(stepGoalPreferencesProvider);
    final faithEnabled = ref.watch(
      userExperienceProfileProvider.select(
        (profile) => profile.value?.faithEnabled ?? false,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'Entrenamiento',
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recordatorio diario'),
                subtitle: Text(
                  kIsWeb
                      ? 'Disponible en Android y iOS.'
                      : 'Aviso a las ${_formatTime(settings.workoutReminderHour, settings.workoutReminderMinute)}.',
                ),
                value: !kIsWeb && settings.workoutRemindersEnabled,
                onChanged: kIsWeb
                    ? null
                    : (enabled) async {
                        await settingsNotifier.setWorkoutReminders(enabled);
                        if (!context.mounted) return;
                        final effective =
                            ref.read(settingsProvider).workoutRemindersEnabled;
                        if (enabled && !effective) {
                          _showPermissionMessage(context);
                        }
                      },
              ),
              if (!kIsWeb) ...[
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Hora'),
                  subtitle: Text(
                    _formatTime(
                      settings.workoutReminderHour,
                      settings.workoutReminderMinute,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: settings.workoutReminderHour,
                        minute: settings.workoutReminderMinute,
                      ),
                    );
                    if (selected != null) {
                      await settingsNotifier.setWorkoutReminderTime(
                        hour: selected.hour,
                        minute: selected.minute,
                      );
                    }
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Hidratación',
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recordarme si falta agua'),
                subtitle: Text(
                  'Meta actual: ${hydrationPrefs.targetMl} ml · '
                  'aviso a las ${hydrationPrefs.reminderHour.toString().padLeft(2, '0')}:00.',
                ),
                value: !kIsWeb && hydrationPrefs.reminderEnabled,
                onChanged: kIsWeb
                    ? null
                    : (enabled) async {
                        final notifier =
                            ref.read(hydrationPreferencesProvider.notifier);
                        await notifier.setReminderEnabled(enabled);
                        final updated = ref.read(hydrationPreferencesProvider);
                        final granted =
                            await HydrationReminderService.syncNextReminder(
                          enabled: updated.reminderEnabled,
                          currentMl: hydration.waterMl,
                          targetMl: updated.targetMl,
                          reminderHour: updated.reminderHour,
                          requestPermissionIfNeeded: enabled,
                        );
                        if (enabled && !granted) {
                          await notifier.setReminderEnabled(false);
                          if (context.mounted) {
                            _showPermissionMessage(context);
                          }
                        }
                      },
              ),
              if (!kIsWeb) ...[
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Hora del aviso'),
                  subtitle: Text(
                    '${hydrationPrefs.reminderHour.toString().padLeft(2, '0')}:00',
                  ),
                  trailing: DropdownButton<int>(
                    value: hydrationPrefs.reminderHour,
                    items: const [12, 15, 18, 20, 22]
                        .map(
                          (hour) => DropdownMenuItem(
                            value: hour,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (hour) async {
                      if (hour == null) return;
                      final notifier =
                          ref.read(hydrationPreferencesProvider.notifier);
                      await notifier.setReminderHour(hour);
                      final updated = ref.read(hydrationPreferencesProvider);
                      await HydrationReminderService.syncNextReminder(
                        enabled: updated.reminderEnabled,
                        currentMl: hydration.waterMl,
                        targetMl: updated.targetMl,
                        reminderHour: updated.reminderHour,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Pasos',
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Avisarme si falta completar la meta'),
                subtitle: Text(
                  'Meta actual: ${stepPrefs.targetSteps} pasos.',
                ),
                value: !kIsWeb && stepPrefs.reminderEnabled,
                onChanged: kIsWeb
                    ? null
                    : (enabled) async {
                        final notifier =
                            ref.read(stepGoalPreferencesProvider.notifier);
                        await notifier.setReminderEnabled(enabled);
                        final updated = ref.read(stepGoalPreferencesProvider);
                        final granted = await StepGoalReminderService.syncToday(
                          preferences: updated,
                          currentSteps: stepState.steps,
                          lastSyncedAt: stepState.lastSyncedAt,
                          requestPermissionIfNeeded: enabled,
                        );
                        if (enabled && !granted) {
                          await notifier.setReminderEnabled(false);
                          if (context.mounted) {
                            _showPermissionMessage(context);
                          }
                        }
                      },
              ),
              if (!kIsWeb && stepPrefs.reminderEnabled) ...[
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Frecuencia'),
                  subtitle: Text(
                    stepPrefs.reminderCadence ==
                            StepReminderCadence.balanced
                        ? 'Inteligente: máximo dos avisos (17:30 y 20:30).'
                        : 'Suave: un aviso a las 20:00.',
                  ),
                  trailing: DropdownButton<StepReminderCadence>(
                    value: stepPrefs.reminderCadence,
                    items: const [
                      DropdownMenuItem(
                        value: StepReminderCadence.balanced,
                        child: Text('Inteligente'),
                      ),
                      DropdownMenuItem(
                        value: StepReminderCadence.gentle,
                        child: Text('Suave'),
                      ),
                    ],
                    onChanged: (cadence) async {
                      if (cadence == null) return;
                      final notifier =
                          ref.read(stepGoalPreferencesProvider.notifier);
                      await notifier.setReminderCadence(cadence);
                      await StepGoalReminderService.syncToday(
                        preferences: ref.read(stepGoalPreferencesProvider),
                        currentSteps: stepState.steps,
                        lastSyncedAt: stepState.lastSyncedAt,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          if (faithEnabled) ...[
            const SizedBox(height: 14),
            _Section(
              title: 'Fortaleza diaria',
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Versículo diario'),
                  subtitle: const Text(
                    'Recordatorio local diario a las 08:00.',
                  ),
                  value: !kIsWeb && settings.dailyVerseNotifications,
                  onChanged: kIsWeb
                      ? null
                      : (enabled) async {
                          await settingsNotifier
                              .setDailyVerseNotifications(enabled);
                          if (!context.mounted) return;
                          final effective = ref
                              .read(settingsProvider)
                              .dailyVerseNotifications;
                          if (enabled && !effective) {
                            _showPermissionMessage(context);
                          }
                        },
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'STK Haven usa recordatorios locales del dispositivo. '
                'La hora se interpreta en la zona horaria actual del teléfono.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showPermissionMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No se concedió permiso para notificaciones. '
          'Puedes activarlo desde los ajustes del sistema.',
        ),
      ),
    );
  }

  static String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        ),
      );
}
