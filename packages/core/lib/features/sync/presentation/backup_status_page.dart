import 'package:core/core/services/backup_activity_service.dart';
import 'package:core/core/services/backup_file_service.dart';
import 'package:core/core/services/backup_service.dart';
import 'package:core/database/hive/hive_boxes.dart';
import 'package:core/features/exercises/presentation/providers/exercise_provider.dart';
import 'package:core/features/habits/application/habit_study_timer_provider.dart';
import 'package:core/features/habits/application/habit_tasks_provider.dart';
import 'package:core/features/habits/application/study_plan_provider.dart';
import 'package:core/features/profile/application/data_export_service.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:core/features/programs/data/training_program_repository.dart';
import 'package:core/features/programs/presentation/providers/training_program_provider.dart';
import 'package:core/features/progress/application/body_measurement_provider.dart';
import 'package:core/features/routines/presentation/providers/routine_provider.dart';
import 'package:core/features/sync/application/cloud_sync_provider.dart';
import 'package:core/features/workout/application/active_workout_provider.dart';
import 'package:core/features/workout/application/workout_history_provider.dart';
import 'package:core/features/workout/presentation/providers/personal_record_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final _backupService = BackupService();
final _backupFileService = BackupFileService();

class BackupStatusPage extends ConsumerWidget {
  const BackupStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(cloudSyncProvider);
    final syncNotifier = ref.read(cloudSyncProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final activity = Hive.box(HiveBoxes.analyticsCache);

    return Scaffold(
      appBar: AppBar(title: const Text('Datos y sincronización')),
      body: ValueListenableBuilder<Box<dynamic>>(
        valueListenable: activity.listenable(
          keys: const [
            BackupActivityService.lastLocalExportKey,
            BackupActivityService.lastRestoreKey,
            BackupActivityService.lastRestoreSourceKey,
          ],
        ),
        builder: (context, _, __) {
          final local = BackupActivityService.lastLocalExportAt;
          final restore = BackupActivityService.lastRestoreAt;
          final restoreSource = BackupActivityService.lastRestoreSource;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Section(
                title: 'Nube',
                children: [
                  if (!cloud.signedIn) ...[
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
                            onPressed: cloud.busy
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
                            onPressed: cloud.busy
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
                      title: Text(cloud.email ?? 'Cuenta de sincronización'),
                      subtitle: Text(
                        cloud.remoteUpdatedAt == null
                            ? 'Todavía no hay copia en la nube.'
                            : 'Última copia: ${_formatDate(cloud.remoteUpdatedAt!)}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Cerrar sesión',
                        onPressed: cloud.busy ? null : syncNotifier.signOut,
                        icon: const Icon(Icons.logout),
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Marcar sincronización como activa'),
                      subtitle: const Text(
                        'La sincronización sigue siendo manual: tú eliges cuándo subir o restaurar.',
                      ),
                      value: settings.cloudSyncEnabled,
                      onChanged: settingsNotifier.setCloudSyncEnabled,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: cloud.busy
                                ? null
                                : syncNotifier.uploadCurrentDevice,
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Subir dispositivo'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: cloud.busy
                                ? null
                                : () async {
                                    final confirmed =
                                        await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: const Text(
                                          'Restaurar copia de la nube',
                                        ),
                                        content: const Text(
                                          'La copia remota reemplazará los datos locales de este dispositivo. No se mezclan datos silenciosamente.',
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
                  if (cloud.busy) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                  ],
                  if (cloud.message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      cloud.message!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cloud.isError
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Copias locales',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.save_alt_rounded),
                    title: const Text('Crear copia local'),
                    subtitle: Text(
                      local == null
                          ? 'Genera un archivo JSON que puedes guardar donde quieras.'
                          : 'Última copia: ${_formatDate(local)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      try {
                        final jsonString = _backupService.createBackup();
                        await _backupFileService.exportFile(jsonString);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Error al crear la copia: $error'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restore_rounded),
                    title: const Text('Restaurar copia local'),
                    subtitle: Text(
                      restore == null
                          ? 'Restaura desde un archivo JSON de STK Haven.'
                          : 'Última restauración: ${_formatDate(restore)}'
                              ' · ${restoreSource ?? 'origen no especificado'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _restoreLocalBackup(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Exportación',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.table_chart_outlined),
                    title: const Text('Exportar entrenamientos a CSV'),
                    subtitle: const Text(
                      'Crea un archivo compatible con Excel y hojas de cálculo.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final history = ref.read(workoutHistoryProvider);
                      if (history.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('No hay entrenamientos para exportar.'),
                          ),
                        );
                        return;
                      }
                      try {
                        await DataExportService()
                            .exportWorkoutsToCSV(history);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error al exportar entrenamientos: $error',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '“Subir” hace que este dispositivo sea la copia remota de referencia. '
                    '“Restaurar” reemplaza los datos locales con la copia elegida. '
                    'STK Haven no mezcla ni sobrescribe silenciosamente.',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _restoreLocalBackup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final activeWorkout = ref.read(activeWorkoutProvider);
    if (activeWorkout.session != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Termina tu entrenamiento actual antes de restaurar una copia.',
          ),
        ),
      );
      return;
    }

    final jsonString = await _backupFileService.pickBackupFile();
    if (jsonString == null) return;

    final result = _backupService.validateBackup(jsonString);
    if (!context.mounted) return;

    if (!result.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.errorMessage ?? 'No se pudo leer esta copia.',
          ),
        ),
      );
      return;
    }

    final parsed = result.parsedData!;
    final routines = (parsed['routines'] as List).length;
    final workouts = (parsed['workouts'] as List).length;
    final exercises = (parsed['exercises'] as List).length;
    final prs = (parsed['personalRecords'] as List).length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar copia local'),
        content: Text(
          'Contenido:\n\n'
          '$routines rutinas\n'
          '$workouts entrenamientos\n'
          '$exercises ejercicios\n'
          '$prs récords personales\n\n'
          'Este proceso reemplazará los datos actuales del dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _backupService.restoreBackup(parsed);
      await TrainingProgramRepository.fromHive().hydrateFromBackupMetadata();
      ref.invalidate(settingsProvider);
      ref.invalidate(userExperienceProfileProvider);
      ref.invalidate(habitTasksProvider);
      ref.invalidate(habitStudyTimerProvider);
      ref.invalidate(studyPlanEnrollmentsProvider);
      ref.invalidate(trainingProgramListProvider);
      ref.invalidate(routineListProvider);
      ref.invalidate(exerciseListProvider);
      ref.invalidate(workoutHistoryProvider);
      ref.invalidate(personalRecordRepositoryProvider);
      ref.invalidate(bodyMeasurementProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copia restaurada correctamente.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restaurar la copia: $error'),
          ),
        );
      }
    }
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

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
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
