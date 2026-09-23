import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/sync/application/cloud_sync_provider.dart';

class PlatformSettingsPage extends ConsumerWidget {
  const PlatformSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final sync = ref.watch(cloudSyncProvider);
    final syncNotifier = ref.read(cloudSyncProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Plataforma y sincronización')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Entrenamiento',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.history_toggle_off),
                title: const Text('Precargar última ejecución'),
                subtitle: const Text(
                  'Al iniciar una rutina, copia opcionalmente peso, reps y RIR desde la última ejecución global del mismo ejercicio. No cambia el rango de reps ni el descanso de la rutina actual.',
                ),
                value: settings.prefillExerciseMemoryByDefault,
                onChanged: settingsNotifier.setPrefillExerciseMemoryByDefault,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.compare_arrows),
                title: const Text('Descanso entre lados'),
                subtitle: const Text(
                  'Para ejercicios unilaterales. Es independiente del descanso después de completar la serie.',
                ),
                trailing: DropdownButton<int>(
                  value: settings.unilateralSideRestSeconds,
                  items: const [0, 30, 45, 60, 90, 120, 180]
                      .map(
                        (seconds) => DropdownMenuItem(
                          value: seconds,
                          child: Text(seconds == 0 ? 'Sin descanso' : '${seconds}s'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      settingsNotifier.setUnilateralSideRestSeconds(value);
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.sync_alt),
                title: const Text('Mismo peso para ambos lados'),
                subtitle: const Text(
                  'Al registrar el segundo lado, conserva automáticamente el peso usado en el primero. Reps y RIR siguen siendo independientes.',
                ),
                value: settings.unilateralSameWeightByDefault,
                onChanged: settingsNotifier.setUnilateralSameWeightByDefault,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.first_page_rounded),
                title: const Text('Lado inicial preferido'),
                subtitle: const Text(
                  'Solo es una guía visual; puedes comenzar por cualquiera en cada serie.',
                ),
                trailing: DropdownButton<PreferredWorkoutSide>(
                  value: settings.preferredUnilateralStartSide,
                  items: PreferredWorkoutSide.values
                      .map(
                        (side) => DropdownMenuItem(
                          value: side,
                          child: Text(side.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      settingsNotifier.setPreferredUnilateralStartSide(value);
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text('Flujo unilateral'),
                subtitle: Text(
                  'Registra un lado, descansa el tiempo configurado y luego registra el otro. Peso, repeticiones y RIR quedan guardados por lado.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Rendimiento y accesibilidad',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.speed_outlined),
                title: const Text('Modo rendimiento'),
                subtitle: Text(
                  switch (settings.performanceMode) {
                    PerformanceMode.automatic =>
                      'Ajusta el coste visual según plataforma y preferencias del sistema.',
                    PerformanceMode.quality =>
                      'Prioriza la presentación visual cuando el dispositivo puede sostenerla.',
                    PerformanceMode.savings =>
                      'Reduce animaciones, efectos y densidad de gráficas antes de sacrificar funcionalidad.',
                  },
                ),
                trailing: DropdownButton<PerformanceMode>(
                  value: settings.performanceMode,
                  items: PerformanceMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(mode.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) settingsNotifier.setPerformanceMode(value);
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reducir movimiento'),
                subtitle: const Text(
                  'Reduce transiciones y animaciones cuando prefieres una interfaz más estable.',
                ),
                value: settings.reduceMotion,
                onChanged: settingsNotifier.setReduceMotion,
              ),
              const Divider(height: 1),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.accessibility_new_outlined),
                title: Text('Preferencias del sistema'),
                subtitle: Text(
                  'STK Haven también respeta el ajuste de reducir movimiento del sistema operativo o navegador.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Notificaciones locales',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recordatorio diario de entrenamiento'),
                subtitle: Text(
                  kIsWeb
                      ? 'Disponible en Android y iOS.'
                      : 'Aviso diario a las ${_formatTime(settings.workoutReminderHour, settings.workoutReminderMinute)}.',
                ),
                value: !kIsWeb && settings.workoutRemindersEnabled,
                onChanged:
                    kIsWeb ? null : settingsNotifier.setWorkoutReminders,
              ),
              if (!kIsWeb) ...[
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Hora del recordatorio'),
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
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Sincronización opcional',
            children: [
              if (!sync.signedIn) ...[
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('Solo local por defecto'),
                  subtitle: Text(
                    'Tus datos permanecen en este dispositivo hasta que decidas iniciar sesión y subir una copia.',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: sync.busy
                            ? null
                            : () => _showAuthDialog(
                                  context,
                                  ref,
                                  createAccount: false,
                                ),
                        icon: const Icon(Icons.login),
                        label: const Text('Iniciar sesión'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: sync.busy
                            ? null
                            : () => _showAuthDialog(
                                  context,
                                  ref,
                                  createAccount: true,
                                ),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Crear cuenta'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_done_outlined),
                  title: Text(sync.email ?? 'Cuenta Supabase'),
                  subtitle: Text(
                    sync.remoteUpdatedAt == null
                        ? 'Todavía no hay copia en la nube.'
                        : 'Última copia: ${_formatDate(sync.remoteUpdatedAt!)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Cerrar sesión',
                    onPressed: sync.busy ? null : syncNotifier.signOut,
                    icon: const Icon(Icons.logout),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Marcar sincronización como activa'),
                  subtitle: const Text(
                    'La sincronización sigue siendo manual: tú decides cuándo subir o restaurar.',
                  ),
                  value: settings.cloudSyncEnabled,
                  onChanged: settingsNotifier.setCloudSyncEnabled,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            sync.busy ? null : syncNotifier.uploadCurrentDevice,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Subir este dispositivo'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: sync.busy
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text(
                                      'Restaurar copia de la nube',
                                    ),
                                    content: const Text(
                                      'La copia remota reemplazará los datos locales de STK Haven en este dispositivo. Usa “Subir este dispositivo” primero si necesitas conservar el estado local actual.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(
                                          dialogContext,
                                          false,
                                        ),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(
                                          dialogContext,
                                          true,
                                        ),
                                        child: const Text('Restaurar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await syncNotifier.restoreFromCloud();
                                }
                              },
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('Restaurar nube'),
                      ),
                    ),
                  ],
                ),
              ],
              if (sync.busy) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ],
              if (sync.message != null) ...[
                const SizedBox(height: 12),
                Text(
                  sync.message!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: sync.isError
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const _SectionCard(
            title: 'Cómo se resuelven los cambios',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.swap_horiz_outlined),
                title: Text('Control explícito'),
                subtitle: Text(
                  '“Subir” hace que este dispositivo sea la nueva copia de referencia. “Restaurar” hace que la nube reemplace este dispositivo. No se mezclan datos silenciosamente ni se sobrescriben en segundo plano.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _showAuthDialog(
    BuildContext context,
    WidgetRef ref, {
    required bool createAccount,
  }) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          createAccount ? 'Crear cuenta de sincronización' : 'Iniciar sesión',
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Correo'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (!text.contains('@') || !text.contains('.')) {
                    return 'Ingresa un correo válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Contraseña'),
                validator: (value) {
                  if ((value ?? '').length < 6) {
                    return 'Usa al menos 6 caracteres.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(createAccount ? 'Crear' : 'Entrar'),
          ),
        ],
      ),
    );

    if (submit == true) {
      final notifier = ref.read(cloudSyncProvider.notifier);
      if (createAccount) {
        await notifier.signUp(
          email: emailController.text,
          password: passwordController.text,
        );
      } else {
        await notifier.signIn(
          email: emailController.text,
          password: passwordController.text,
        );
      }
    }
    emailController.dispose();
    passwordController.dispose();
  }

  static String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
